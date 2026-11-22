# Environment Configurations

These directories are **standalone Terraform roots** for specific cloud combinations. Use the one that matches your target providers so you only configure credentials for the clouds you use.

## Available environments

| Environment     | Providers   | Use when you need...        |
|----------------|-------------|-----------------------------|
| `aks`          | Azure only  | AKS clusters only           |
| `eks`          | AWS only    | EKS clusters only           |
| `gke`          | GCP only    | GKE clusters only           |
| `aks-eks`       | Azure + AWS | AKS and EKS                 |
| `aks-gke`      | Azure + GCP | AKS and GKE                 |
| `eks-gke`      | AWS + GCP   | EKS and GKE                 |
| `eks-rosa`     | AWS only    | EKS and ROSA (HCP), same region |
| `multicluster` | All three   | AKS, EKS, and GKE together  |
| `dns-delegation` | AWS only  | Delegating a child zone hosted in another cloud's native DNS from the primary Route53 parent zone (NS record only -- doesn't provision any cluster) |
| `eks-ipv6`     | AWS only    | EKS IPv6 dual-stack clusters with Transit Gateway mesh and optional bastion |

## How to use

1. **Pick an environment** (e.g. `gke` if you only use GCP).

2. **Run Terraform from that directory:**
   ```bash
   cd environments/gke
   terraform init
   terraform plan -var-file=my.tfvars
   terraform apply -var-file=my.tfvars
   ```
   Or from the repo root:
   ```bash
   terraform -chdir=environments/gke init
   terraform -chdir=environments/gke plan -var-file=environments/gke/my.tfvars
   terraform -chdir=environments/gke apply -var-file=environments/gke/my.tfvars
   ```

3. **Configure only the providers that environment uses:**
   - **aks**: `az login` (or Azure env vars / service principal).
   - **eks** / **eks-ipv6**: AWS credentials (profile, env vars, or IAM role).
   - **gke**: GCP credentials (`gcloud auth application-default login` or service account).

Each environment’s `providers.tf` declares only the provider(s) it needs. Provider version constraints come from the shared modules under `modules/`, so you are not forced to set up unused cloud credentials.

**Default Kubernetes version (single place):** The default version for all clusters (AKS, EKS, GKE) is defined once in **`modules/defaults/variables.tf`** (variable `kubernetes_version`, default `1.34`). Every environment uses this via the `defaults` module; you only change it there to update the default everywhere. To override per run: `-var kubernetes_version=1.35` or set `kubernetes_version` in your tfvars.

## Example tfvars files

Sample variable files live in `examples/`. Use the one that matches your target environment:

| Example file | Target environment | Notes |
|---|---|---|
| `eks-single-cluster.tfvars` | `environments/eks` | Single EKS cluster; DNS vars commented out |
| `eks-three-clusters.tfvars` | `environments/eks` | Three EKS clusters (`eks_cluster_count = 3`) |
| `clusters-in-all-cloudproviders.tfvars` | `environments/multicluster` | All three providers; AKS service principal required |
| `eks-ipv6.tfvars` | `environments/eks-ipv6` | IPv6 dual-stack; bastion enabled by default |

Each example covers required variables and shows optional ones as comments. Copy the relevant file, edit values, then pass it with `-var-file=my.tfvars`.

## Node sleep schedule

**What it does:** Automatically scale EKS worker nodes to zero on a recurring schedule (e.g. after hours or weekends) to save EC2 compute cost, then scale back up at a specified time. The schedule is implemented via Terraform-managed `aws_autoscaling_schedule` resources (`eks_worker_sleep` and `eks_worker_wake`) that act directly on the worker Auto Scaling Group. Use the on-demand script below to manually sleep/wake a cluster outside the schedule.

**Cost caveat:** This saves EC2 compute cost only. It does NOT reduce the EKS control plane fee (billed per cluster regardless of node count) or NAT Gateway charges (still active even with zero nodes).

**Important - affects every environment with EKS, whether or not you use node sleep:** The worker ASG has `lifecycle { ignore_changes = [desired_capacity] }`, unconditionally, so that the sleep schedule and the on-demand script can manage `desired_capacity` without Terraform fighting them on the next apply. One consequence: `eks_nodes` now only sets a cluster's *initial* desired node count. Changing `eks_nodes` and re-applying no longer resizes an already-running cluster. To resize a running cluster's node count going forward, use `scripts/eks-node-sleep.sh <env> <cluster-index> wake --min N --max N --desired N` with your new numbers.

**Prerequisites:** To use the sleep schedule, set `eks_min_nodes = 0` in your tfvars. Terraform enforces this with a precondition, as AWS does not allow `desired_capacity` to drop below `min_size`.

**Variables (available in every environment that includes EKS: `eks`, `multicluster`, `eks-gke`, `eks-rosa`, `aks-eks`):**

| Variable | Type | Default | Description |
|---|---|---|---|
| `enable_node_sleep_schedule` | bool | `false` | Enable the recurring sleep schedule |
| `node_sleep_cron` | string | `"30 18 * * MON-FRI"` | Cron expression (5-field, in `node_sleep_timezone`) to scale nodes to zero |
| `node_wake_cron` | string | `"0 8 * * MON-FRI"` | Cron expression (5-field, in `node_sleep_timezone`) to scale nodes back up |
| `node_sleep_timezone` | string | `"UTC"` | IANA time zone for the cron expressions (e.g. `"America/New_York"`) |

**On-demand sleep/wake:**

Use `scripts/eks-node-sleep.sh` to manually control node scaling independent of the schedule.

Syntax: `scripts/eks-node-sleep.sh <environment-dir> <cluster-index> <sleep|wake> [options]`

Sleep (no flags needed; only sets desired capacity to 0, leaving min/max unchanged):
```bash
scripts/eks-node-sleep.sh environments/eks 0 sleep
```

Wake (must supply the same values as your `eks_min_nodes`, `eks_max_nodes`, `eks_nodes` tfvars):
```bash
scripts/eks-node-sleep.sh environments/eks 0 wake --min 0 --max 3 --desired 2
```

Options:
- `--min N` required for `wake`, rejected for `sleep`
- `--max N` required for `wake`, rejected for `sleep`
- `--desired N` required for `wake`, rejected for `sleep`
- `--profile NAME` AWS CLI profile name
- `--region NAME` AWS region
- `--dry-run` print the AWS CLI command instead of executing it
