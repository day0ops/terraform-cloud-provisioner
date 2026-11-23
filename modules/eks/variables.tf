variable "enable_eks" {
  description = "Enable / Disable Amazon Web Services EKS (Default: `false`)"
  type        = bool
  default     = false
}

variable "enable_workload_storage" {
  description = "Create an S3 bucket + IRSA role, bound to a given Kubernetes ServiceAccount -- generic object storage for whatever workload needs it (Default: `false`)"
  type        = bool
  default     = false
}

variable "workload_storage_ksa_namespace" {
  description = "Namespace of the Kubernetes ServiceAccount to bind the storage IRSA role to"
  type        = string
  default     = ""
}

variable "workload_storage_ksa_name" {
  description = "Names of the Kubernetes ServiceAccounts to bind the storage IRSA role to -- every workload that touches the bucket directly needs its own binding (e.g. Agent Substrate's atelet AND ate-api-server, which independently manages golden-snapshot Tags)"
  type        = list(string)
  default     = []
}

variable "workload_storage_force_destroy" {
  description = "Allow Terraform to delete the workload storage bucket even if it still contains objects (Default: `false`)"
  type        = bool
  default     = false
}

variable "eks_region" {
  description = "AWS region for EKS (Default: `ap-southeast-2`, Ref: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html)"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "AWS cli profile (Default: `default`)"
  type        = string
  default     = "default"

  validation {
    condition     = can(length(var.aws_profile) > 0)
    error_message = "AWS profile must be provided."
  }
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string

  validation {
    condition     = can(length(var.eks_cluster_name) > 0)
    error_message = "EKS cluster name must be provided."
  }
}

variable "eks_cluster_index" {
  description = "EKS cluster index when multiple clusters are required"
  type        = string
}

variable "eks_nodes" {
  description = "EKS Kubernetes worker nodes, desired ASG capacity (e.g. `2`)"
  type        = number
  default     = 2
}

variable "eks_min_nodes" {
  description = "EKS Kubernetes worker nodes, minimum ASG capacity (e.g. `1`)"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "EKS Kubernetes worker nodes, maximum ASG capacity (e.g. `3`)"
  type        = number
  default     = 3
}

variable "eks_node_type" {
  description = "AWS EC2 node instance type (Default: `t3.medium`, Ref: https://aws.amazon.com/ec2/instance-types)"
  type        = string
  default     = "t3.medium"
}

variable "eks_cidr_block" {
  description = "AWS VPC CIDR block (Default: `10.0.0.0/16`)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_subnets" {
  description = "List of 8-bit numbers of subnets (Default: `2`)"
  type        = number
  default     = 2
}

variable "eks_private_nodes" {
  description = "Place worker nodes in private subnets behind the NAT Gateway instead of public subnets (Default: `false`)"
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (default: 1.34)"
  type        = string
  default     = "1.34"
}

# -- Node sleep schedule

variable "enable_node_sleep_schedule" {
  description = "Scale worker nodes to zero on a recurring schedule to save cost when the cluster is idle (Default: `false`)"
  type        = bool
  default     = false
}

variable "node_sleep_cron" {
  description = "Cron expression (5-field, in `node_sleep_timezone`) for when worker nodes scale to zero (Default: `30 18 * * MON-FRI`)"
  type        = string
  default     = "30 18 * * MON-FRI"
}

variable "node_wake_cron" {
  description = "Cron expression (5-field, in `node_sleep_timezone`) for when worker nodes scale back up to `eks_nodes`/`eks_min_nodes`/`eks_max_nodes` (Default: `0 8 * * MON-FRI`)"
  type        = string
  default     = "0 8 * * MON-FRI"
}

variable "node_sleep_timezone" {
  description = "IANA time zone for `node_sleep_cron` / `node_wake_cron` (Default: `UTC`)"
  type        = string
  default     = "UTC"
}

# -- Tagging and labeling

variable "owner" {
  description = "Name of the maintainer of the EKS cluster"
  type        = string
}

variable "team" {
  description = "Team that maintains the cluster"
  type        = string
}

variable "purpose" {
  description = "Purpose for the cluster"
  type        = string
}

variable "extra_tags" {
  description = "Tags used for the EKS resources"
  type        = map(string)
  default     = {}
}

# -- DNS

variable "enable_dns" {
  description = "Enable Route53 child zone and worker node Route53 IAM policy"
  type        = bool
  default     = false
}

