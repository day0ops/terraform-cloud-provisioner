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

variable "rosa_region" {
  description = "AWS region for ROSA"
  type        = string
  default     = "us-east-1"
}

variable "rosa_openshift_version" {
  description = "OpenShift version to install, e.g. 4.19.0. The upstream rosa-hcp module requires a concrete value (no installer-side default)"
  type        = string
  default     = "4.19.0"
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
