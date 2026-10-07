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
  description = "Override Kubernetes version (default from modules/defaults)"
  type        = string
  default     = null
}

variable "gke_release_channel" {
  description = "GKE release channel (STABLE, REGULAR, RAPID)"
  type        = string
  default     = "STABLE"
}

variable "gke_enable_beta_apis" {
  description = "Kubernetes beta APIs to whitelist on the cluster (e.g. certificates.k8s.io/v1beta1)"
  type        = list(string)
  default     = []
}

variable "gke_enable_workload_identity" {
  description = "Enable GKE Workload Identity Federation for GCP"
  type        = bool
  default     = false
}

variable "gke_disable_filestore_csi" {
  description = "Disable the Filestore CSI driver addon"
  type        = bool
  default     = false
}

variable "gke_node_auto_upgrade" {
  description = "Node auto-upgrade for the worker pool"
  type        = bool
  default     = true
}

variable "gke_restrict_control_plane_access" {
  description = "Restrict the control plane's public endpoint to the applying workstation's own IP (Default: `false` -- open to the internet)"
  type        = bool
  default     = false
}

variable "enable_workload_storage" {
  description = "Create a GCS bucket + GSA, bound via Workload Identity to a given Kubernetes ServiceAccount -- generic object storage for whatever workload needs it"
  type        = bool
  default     = false
}

variable "workload_storage_ksa_namespace" {
  description = "Namespace of the Kubernetes ServiceAccount to bind the storage GSA to"
  type        = string
  default     = ""
}

variable "workload_storage_ksa_name" {
  description = "Names of the Kubernetes ServiceAccounts to bind the storage GSA to"
  type        = list(string)
  default     = []
}

# -- DNS: this environment only ever manages its own Cloud DNS zone. The external Route53
# parent's NS delegation record is created separately (environments/dns-delegation) -- this
# environment only needs the parent domain to compute its own zone's FQDN, never the parent
# zone's ID or AWS credentials.

variable "enable_dns" {
  description = "Enable the Cloud DNS child zone"
  type        = bool
  default     = false
}

variable "dns_parent_domain" {
  description = "Parent domain this zone is a child of (e.g., kasunt.apac.fe.solo.io) -- used only to compute this zone's own FQDN"
  type        = string
  default     = null
}

variable "dns_child_zone_name" {
  description = "Child zone subdomain (e.g., agentic-demo-gke)"
  type        = string
  default     = null
}

# ----------------------------------------------------------------------------------
# GKE
# ----------------------------------------------------------------------------------

variable "gke_project" {
  description = "GCP Project ID for GKE"
  type        = string
}

variable "gke_region" {
  description = "GCP region for GKE"
  type        = string
  default     = "australia-southeast1"
}

variable "gke_cluster_count" {
  description = "Number of GKE clusters"
  type        = number
  default     = 1
}

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "gke_node_pool_size" {
  description = "GKE Kubernetes worker nodes"
  type        = number
  default     = 3
}

variable "gke_node_type" {
  description = "GKE node instance type"
  type        = string
  default     = "n1-standard-2"
}
