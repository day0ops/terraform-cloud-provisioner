#!/usr/bin/env bash
# On-demand sleep/wake for an EKS environment's worker Auto Scaling Group.
#
# Looks up the target ASG name from an environment's `eks_worker_asg_names`
# Terraform output and resizes it directly via the AWS CLI, independent of
# the Terraform-managed recurring sleep schedule.
set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

print_usage() {
  cat >&2 <<EOF
Usage: $SCRIPT_NAME <environment-dir> <cluster-index> <sleep|wake> [options]

Positional:
  environment-dir   Path to a Terraform environment directory with applied state (e.g. environments/eks)
  cluster-index     0-based index into that environment's eks_worker_asg_names output
  action            "sleep" or "wake"

Options:
  --min N           min_size to set (required for wake, rejected for sleep)
  --max N           max_size to set (required for wake, rejected for sleep)
  --desired N       desired_capacity to set (required for wake, rejected for sleep)
  --profile NAME    passed through as --profile to the aws cli
  --region NAME     passed through as --region to the aws cli
  --dry-run         print the aws cli command instead of running it
EOF
}

usage_error() {
  echo "Error: $1" >&2
  print_usage
  exit 1
}

is_nonneg_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

check_dependencies() {
  local missing=() bin
  for bin in terraform aws jq; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: required command(s) not found on PATH: ${missing[*]}" >&2
    exit 1
  fi
}

# Prints the ASG name at $2 in $1's eks_worker_asg_names output to stdout.
# Exits 2 (from within the command-substitution subshell, propagated by the
# caller) on any lookup failure: terraform error, unparsable output, empty
# list, or out-of-range index.
lookup_asg_name() {
  local env_dir="$1" index="$2" output_json err_file count

  err_file=$(mktemp)
  if ! output_json=$(terraform -chdir="$env_dir" output -json eks_worker_asg_names 2>"$err_file"); then
    echo "Error: 'terraform output -json eks_worker_asg_names' failed in '$env_dir' (not initialized/applied, or the output is missing)." >&2
    cat "$err_file" >&2
    rm -f "$err_file"
    exit 2
  fi
  rm -f "$err_file"

  if ! count=$(jq 'length' <<<"$output_json" 2>/dev/null); then
    echo "Error: could not parse 'eks_worker_asg_names' output as a JSON array in '$env_dir'." >&2
    exit 2
  fi
  if (( count == 0 )); then
    echo "Error: 'eks_worker_asg_names' output in '$env_dir' is empty; no worker ASGs to target." >&2
    exit 2
  fi
  if (( 10#$index >= count )); then
    echo "Error: cluster-index $index is out of range for '$env_dir' (valid range: 0-$((count - 1)))." >&2
    exit 2
  fi

  jq -r ".[$index]" <<<"$output_json"
}

# Resizes the ASG via the AWS CLI, or prints the command when dry_run=true.
run_aws_update() {
  local asg_name="$1" min="$2" max="$3" desired="$4" profile="$5" region="$6" dry_run="$7"
  local -a cmd=(aws autoscaling update-auto-scaling-group
    --auto-scaling-group-name "$asg_name"
    --min-size "$min"
    --max-size "$max"
    --desired-capacity "$desired")
  [[ -n "$profile" ]] && cmd+=(--profile "$profile")
  [[ -n "$region" ]] && cmd+=(--region "$region")

  if [[ "$dry_run" == true ]]; then
    echo "${cmd[*]}"
    return 0
  fi

  if ! "${cmd[@]}"; then
    echo "Error: 'aws autoscaling update-auto-scaling-group' failed for ASG '$asg_name'." >&2
    exit 3
  fi
}

main() {
  check_dependencies

  if [[ $# -lt 3 ]]; then
    usage_error "missing required arguments"
  fi

  local environment_dir="$1" cluster_index="$2" action="$3"
  shift 3

  is_nonneg_int "$cluster_index" || usage_error "cluster-index must be a non-negative integer, got '$cluster_index'"
  case "$action" in
    sleep | wake) ;;
    *) usage_error "action must be 'sleep' or 'wake', got '$action'" ;;
  esac

  local min_val="" max_val="" desired_val="" profile="" region="" dry_run=false
  local min_set=false max_set=false desired_set=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --min)
        [[ $# -ge 2 ]] || usage_error "--min requires a value"
        min_val="$2" min_set=true
        shift 2
        ;;
      --max)
        [[ $# -ge 2 ]] || usage_error "--max requires a value"
        max_val="$2" max_set=true
        shift 2
        ;;
      --desired)
        [[ $# -ge 2 ]] || usage_error "--desired requires a value"
        desired_val="$2" desired_set=true
        shift 2
        ;;
      --profile)
        [[ $# -ge 2 ]] || usage_error "--profile requires a value"
        profile="$2"
        shift 2
        ;;
      --region)
        [[ $# -ge 2 ]] || usage_error "--region requires a value"
        region="$2"
        shift 2
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      *)
        usage_error "unknown option '$1'"
        ;;
    esac
  done

  if [[ "$action" == "sleep" ]]; then
    if $min_set || $max_set || $desired_set; then
      usage_error "--min/--max/--desired are not allowed with 'sleep' (it always targets 0/0/0)"
    fi
    min_val=0 max_val=0 desired_val=0
  else
    if ! $min_set || ! $max_set || ! $desired_set; then
      usage_error "'wake' requires --min, --max, and --desired"
    fi
    is_nonneg_int "$min_val" || usage_error "--min must be a non-negative integer, got '$min_val'"
    is_nonneg_int "$max_val" || usage_error "--max must be a non-negative integer, got '$max_val'"
    is_nonneg_int "$desired_val" || usage_error "--desired must be a non-negative integer, got '$desired_val'"
  fi

  local asg_name
  if ! asg_name=$(lookup_asg_name "$environment_dir" "$cluster_index"); then
    exit 2
  fi

  run_aws_update "$asg_name" "$min_val" "$max_val" "$desired_val" "$profile" "$region" "$dry_run"
}

main "$@"
