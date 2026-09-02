variable "owner" {
  description = "Name of the maintainer of the cluster"
  type        = string
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

variable "rosa_region" {
  description = "AWS region for the ROSA cluster"
  type        = string
  default     = "us-east-1"
}

variable "rosa_cluster_name" {
  description = "ROSA cluster name"
  type        = string
}

variable "rosa_cluster_index" {
  description = "1-based index of this cluster instance, used to namespace generated resources and output files when count > 1"
  type        = number
  default     = 1
}

variable "rosa_openshift_version" {
  description = "OpenShift version to install, e.g. 4.19.0. Leave null to let the installer pick the default"
  type        = string
  default     = null
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
  description = "Number of AZs to spread the cluster's VPC subnets across"
  type        = number
  default     = 2
}
