variable "aws_profile" {
  description = "AWS CLI profile used to write into the Route53 parent zone"
  type        = string
  default     = null
}

variable "dns_parent_zone_id" {
  description = "Route53 parent hosted zone ID (the primary DNS zone, always Route53-hosted)"
  type        = string

  validation {
    condition     = length(var.dns_parent_zone_id) > 0
    error_message = "Route53 parent hosted zone ID must be provided."
  }
}

variable "dns_parent_domain" {
  description = "Parent domain (e.g., kasunt.apac.fe.solo.io)"
  type        = string

  validation {
    condition     = length(var.dns_parent_domain) > 0
    error_message = "Parent domain must be provided."
  }
}

variable "dns_child_zone_name" {
  description = "Child zone subdomain being delegated (e.g., agentic-demo-gke)"
  type        = string

  validation {
    condition     = length(var.dns_child_zone_name) > 0
    error_message = "Child zone subdomain must be provided."
  }
}

variable "dns_child_nameservers" {
  description = "Name servers of the child zone's own cloud-native DNS (e.g. Cloud DNS or Azure DNS), to delegate to"
  type        = list(string)

  validation {
    condition     = length(var.dns_child_nameservers) > 0
    error_message = "At least one child zone name server must be provided."
  }
}
