#!/usr/bin/env bash
# Smoke tests for eks-node-sleep.sh. Plain bash, no external test framework.
#
# Each test_* function runs the script as a subprocess and asserts on its
# exit code and/or stdout/stderr. The script's own exit code is the number
# of failed assertions (0 = all passed).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/eks-node-sleep.sh"

# A directory that does not exist on disk. Used for the usage-error tests so
# that if argument validation ever ran *after* a terraform call, the test
# would fail with exit 2 (terraform lookup failure) instead of the expected
# exit 1, proving validation happens first.
NONEXISTENT_DIR="/tmp/eks-node-sleep-test-nonexistent-$$"

failures=0

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

# Runs the script with the given args, capturing stdout/stderr/exit code
# into RUN_STDOUT / RUN_STDERR / RUN_STATUS.
run_script() {
  local out err
  out=$(mktemp)
  err=$(mktemp)
  "$SCRIPT" "$@" >"$out" 2>"$err"
  RUN_STATUS=$?
  RUN_STDOUT=$(cat "$out")
  RUN_STDERR=$(cat "$err")
  rm -f "$out" "$err"
}

assert_exit_code() {
  local expected="$1" label="$2"
  if [[ "$RUN_STATUS" -ne "$expected" ]]; then
    fail "$label: expected exit $expected, got $RUN_STATUS (stderr: $RUN_STDERR)"
    return 1
  fi
  return 0
}

assert_stderr_contains() {
  local needle="$1" label="$2"
  if [[ "$RUN_STDERR" != *"$needle"* ]]; then
    fail "$label: expected stderr to contain '$needle', got: $RUN_STDERR"
    return 1
  fi
  return 0
}

test_no_args_is_usage_error() {
  run_script
  assert_exit_code 1 "test_no_args_is_usage_error"
}

test_unknown_action_is_usage_error() {
  run_script "$NONEXISTENT_DIR" 0 snooze
  assert_exit_code 1 "test_unknown_action_is_usage_error"
}

test_non_numeric_cluster_index() {
  run_script "$NONEXISTENT_DIR" abc sleep
  assert_exit_code 1 "test_non_numeric_cluster_index"
}

test_sleep_rejects_min_max_desired() {
  run_script "$NONEXISTENT_DIR" 0 sleep --min 1
  assert_exit_code 1 "test_sleep_rejects_min_max_desired"
}

test_wake_requires_min_max_desired() {
  run_script "$NONEXISTENT_DIR" 0 wake --min 1
  assert_exit_code 1 "test_wake_requires_min_max_desired"
}

test_missing_state_dir_exit_code_2() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  run_script "$tmp_dir" 0 sleep
  assert_exit_code 2 "test_missing_state_dir_exit_code_2"
  assert_stderr_contains "$tmp_dir" "test_missing_state_dir_exit_code_2 (message should name the directory)"
  rm -rf "$tmp_dir"
}

# Bonus: exercise --dry-run end to end with fake terraform/aws binaries ahead
# on PATH, since no real applied Terraform state or AWS credentials are
# available here. Confirms the printed command includes the looked-up ASG
# name and that the real `aws` binary is never invoked.
test_dry_run_prints_command_and_skips_aws() {
  local fakebin tf_env sentinel
  fakebin=$(mktemp -d)
  tf_env=$(mktemp -d)
  sentinel=$(mktemp -u)

  cat >"$fakebin/terraform" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"output -json eks_worker_asg_names"* ]]; then
  echo '["asg-fake-1","asg-fake-2"]'
  exit 0
fi
echo "fake terraform: unsupported invocation: $*" >&2
exit 1
EOF
  chmod +x "$fakebin/terraform"

  cat >"$fakebin/aws" <<EOF
#!/usr/bin/env bash
echo called >"$sentinel"
exit 0
EOF
  chmod +x "$fakebin/aws"

  local PATH="$fakebin:$PATH"
  run_script "$tf_env" 0 wake --min 1 --max 3 --desired 2 --dry-run

  assert_exit_code 0 "test_dry_run_prints_command_and_skips_aws"
  if [[ "$RUN_STDOUT" != *"autoscaling update-auto-scaling-group"* ]]; then
    fail "test_dry_run_prints_command_and_skips_aws: expected stdout to contain the aws command, got: $RUN_STDOUT"
  fi
  if [[ "$RUN_STDOUT" != *"asg-fake-1"* ]]; then
    fail "test_dry_run_prints_command_and_skips_aws: expected stdout to reference the looked-up ASG name, got: $RUN_STDOUT"
  fi
  if [[ -f "$sentinel" ]]; then
    fail "test_dry_run_prints_command_and_skips_aws: aws was invoked but --dry-run must not call it"
  fi

  rm -rf "$fakebin" "$tf_env"
  rm -f "$sentinel"
}

# Bonus: the brief also calls out an out-of-range cluster-index as its own
# exit-2 case, distinct from "no state dir". Uses the same fake-terraform
# trick as the dry-run test to simulate a real, but short, ASG list.
test_out_of_range_cluster_index_exit_code_2() {
  local fakebin tf_env
  fakebin=$(mktemp -d)
  tf_env=$(mktemp -d)

  cat >"$fakebin/terraform" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"output -json eks_worker_asg_names"* ]]; then
  echo '["asg-fake-1","asg-fake-2"]'
  exit 0
fi
echo "fake terraform: unsupported invocation: $*" >&2
exit 1
EOF
  chmod +x "$fakebin/terraform"

  local PATH="$fakebin:$PATH"
  run_script "$tf_env" 99 sleep

  assert_exit_code 2 "test_out_of_range_cluster_index_exit_code_2"
  assert_stderr_contains "out of range" "test_out_of_range_cluster_index_exit_code_2 (message should explain the problem)"

  rm -rf "$fakebin" "$tf_env"
}

for t in \
  test_no_args_is_usage_error \
  test_unknown_action_is_usage_error \
  test_non_numeric_cluster_index \
  test_sleep_rejects_min_max_desired \
  test_wake_requires_min_max_desired \
  test_missing_state_dir_exit_code_2 \
  test_dry_run_prints_command_and_skips_aws \
  test_out_of_range_cluster_index_exit_code_2
do
  "$t"
done

if [[ "$failures" -eq 0 ]]; then
  echo "All tests passed."
else
  echo "$failures test(s) failed."
fi

exit "$failures"
