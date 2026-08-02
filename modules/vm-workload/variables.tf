variable "enable" {
  description = "Provision the VM workload instance (Default: false)"
  type        = bool
  default     = false
}

variable "owner" {
  description = "Name of the maintainer of the cluster"
  type        = string
}

variable "prefix_name" {
  description = "Prefix name for VM workload resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the VM workload will be hosted"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the VM workload instance"
  type        = string
}

variable "cluster_worker_security_group_id" {
  description = "EKS worker security group ID, allowed to reach the VM workload's ztunnel HBONE port"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the VM workload (Default: t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Tags for all VM workload resources"
  type        = map(string)
  default     = {}
}
