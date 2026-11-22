# ----------------------------------------------------------------------------------
# Common
# ----------------------------------------------------------------------------------

variable "owner" {
  description = "Name of the maintainer of the cluster"
  type        = string

  validation {
    condition     = length(var.owner) > 0
    error_message = "Maintainer of the cluster must be provided."
  }
}

variable "team" {
  description = "Team that maintains the cluster"
  type        = string
  default     = "fe-presale"
}

variable "purpose" {
  description = "Purpose for the cluster"
  type        = string
  default     = "pre-sales"
}

variable "kubernetes_version" {
  description = "Override Kubernetes version (default from modules/defaults). Applies to EKS only — ROSA's OpenShift version is set separately via rosa_openshift_version."
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------------
# EKS
# ----------------------------------------------------------------------------------

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "default"
}

variable "eks_region" {
  description = "AWS region for EKS and ROSA (both share this environment's one aws provider)"
  type        = string
  default     = "ap-southeast-2"
}

variable "eks_cluster_count" {
  description = "Number of EKS clusters"
  type        = number
  default     = 1
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_nodes" {
  description = "EKS Kubernetes worker nodes (desired ASG capacity)"
  type        = number
  default     = 2
}

variable "eks_min_nodes" {
  description = "EKS minimum ASG capacity"
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "EKS maximum ASG capacity"
  type        = number
  default     = 3
}

variable "eks_node_type" {
  description = "AWS EC2 node instance type"
  type        = string
  default     = "t3.medium"
}

variable "eks_subnets" {
  description = "Number of subnets"
  type        = number
  default     = 2
}

# -- Node sleep schedule

variable "enable_node_sleep_schedule" {
  description = "Scale worker nodes to zero on a recurring schedule to save cost when idle"
  type        = bool
  default     = false
}

variable "node_sleep_cron" {
  description = "Cron expression for when worker nodes scale to zero"
  type        = string
  default     = "30 18 * * MON-FRI"
}

variable "node_wake_cron" {
  description = "Cron expression for when worker nodes scale back up"
  type        = string
  default     = "0 8 * * MON-FRI"
}

variable "node_sleep_timezone" {
  description = "IANA time zone for node_sleep_cron / node_wake_cron"
  type        = string
  default     = "UTC"
}

# ----------------------------------------------------------------------------------
# ROSA
# ----------------------------------------------------------------------------------

variable "rosa_cluster_count" {
  description = "Number of ROSA clusters"
  type        = number
  default     = 1
}

variable "rosa_cluster_name" {
  description = "ROSA cluster name"
  type        = string
}

variable "rosa_openshift_version" {
  description = "OpenShift version to install, e.g. 4.19.44. The upstream rosa-hcp module requires a concrete value (no installer-side default). Red Hat retires old patch versions from OCM on a rolling basis, so this default will need to be bumped periodically to a version still in the supported list."
  type        = string
  default     = "4.19.44"
}

variable "rosa_compute_machine_type" {
  description = "EC2 instance type for the default worker machine pool"
  type        = string
  default     = "m5.xlarge"
}

variable "rosa_replicas" {
  description = "Number of worker nodes. Must be a multiple of rosa_availability_zones_count (HCP requirement)"
  type        = number
  default     = 2
}

variable "rosa_availability_zones_count" {
  description = "Number of AZs to spread each cluster's VPC subnets across"
  type        = number
  default     = 2
}

# ----------------------------------------------------------------------------------
# DNS
# ----------------------------------------------------------------------------------

variable "enable_dns" {
  description = "Enable Route53 child zone and worker node Route53 IAM policy"
  type        = bool
  default     = false
}

variable "dns_parent_zone_id" {
  description = "Route53 parent hosted zone ID"
  type        = string
  default     = null
}

variable "dns_parent_domain" {
  description = "Parent domain (e.g., kasunt.apac.fe.solo.io)"
  type        = string
  default     = null
}

variable "dns_child_zone_name" {
  description = "Child zone subdomain (e.g., demo)"
  type        = string
  default     = null
}
