variable "enable_gke" {
  description = "Enable / Disable Google GKE (Default: `false`)"
  type        = bool
  default     = false
}

variable "gke_project" {
  description = "GCP Project ID for GKE"
  type        = string

  validation {
    condition     = can(length(var.gke_project) > 0)
    error_message = "GKE project ID of the cluster must be provided."
  }
}

variable "gke_region" {
  description = "GCP region for GKE (Default: `australia-southeast1`, Ref: https://cloud.google.com/compute/docs/regions-zones)"
  type        = string
  default     = "australia-southeast1"
}

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string

  validation {
    condition     = can(length(var.gke_cluster_name) > 0)
    error_message = "GKE cluster name must be provided."
  }
}

variable "gke_cluster_index" {
  description = "GKE cluster index when multiple clusters are required"
  type        = string
}

variable "enable_gke_regional_cluster" {
  description = "Create regional GKE cluster instead of zonal (Default: `false`)"
  type        = bool
  default     = false
}

variable "gke_node_pool_size" {
  description = "GKE Kubernetes worker nodes (Default: `3`)"
  type        = number
  default     = 3
}

variable "enable_gke_preemptible" {
  description = "Use GKE preemptible nodes (Default: `false`)"
  type        = bool
  default     = false
}

variable "gke_node_type" {
  description = "GKE node instance type (Default: `n1-standard-2`, Ref: https://cloud.google.com/compute/docs/general-purpose-machines)"
  type        = string
  default     = "n1-standard-2"
}

variable "gke_node_image_type" {
  description = "The image to use for this node (Default: `cos_containerd`, Ref: https://cloud.google.com/kubernetes-engine/docs/concepts/node-images)"
  type        = string
  default     = "cos_containerd"
}

variable "gke_serviceaccount" {
  description = "GCP default service account for GKE"
  type        = string
  default     = "default"
}

variable "gke_serviceaccount_description" {
  description = "The description of the custom service account for GKE"
  type        = string
  default     = ""
}

variable "gke_serviceaccount_roles" {
  description = "Additional roles to be added to the service account for GKE"
  type        = list(string)
  default     = []
}

variable "enable_gke_hpa" {
  description = "Horizontal pod autoscaling for replicate controller to scale the pods (Default: `true`)"
  type        = bool
  default     = true
}

variable "gke_oauth_scopes" {
  description = "GCP OAuth scopes for GKE (Ref: https://www.terraform.io/docs/providers/google/r/container_cluster.html#oauth_scopes)"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring"
  ]
}

variable "kubernetes_version" {
  description = "GKE Kubernetes version (default: 1.34)"
  type        = string
  default     = "1.34"
}

variable "gke_release_channel" {
  description = "GKE release channel (STABLE, REGULAR, RAPID). RAPID is required to reach k8s 1.37, which Agent Substrate needs for PodCertificateRequest/ClusterTrustBundle to be GA (Default: `STABLE`)"
  type        = string
  default     = "STABLE"
}

variable "gke_enable_beta_apis" {
  description = "Kubernetes beta APIs to whitelist on the cluster (e.g. `certificates.k8s.io/v1beta1` for Agent Substrate). Empty means none (Default: `[]`)"
  type        = list(string)
  default     = []
}

variable "gke_enable_workload_identity" {
  description = "Enable GKE Workload Identity Federation for GCP, so pods can assume GCP service accounts without key files (Default: `false`)"
  type        = bool
  default     = false
}

variable "gke_disable_filestore_csi" {
  description = "Disable the Filestore CSI driver addon (Default: `false`, GCP's own default). Agent Substrate recommends disabling it."
  type        = bool
  default     = false
}

variable "gke_node_auto_upgrade" {
  description = "Node auto-upgrade for the worker pool (Default: `true`, GKE's own default). Agent Substrate requires this off on any pool running workers -- auto-upgrade forwards SIGTERM into actor containers on Google's own maintenance schedule, and an actor still awake after the 30-minute suspend window moves to a terminal CRASHED state."
  type        = bool
  default     = true
}

variable "enable_workload_storage" {
  description = "Create a GCS bucket + GSA, bound via Workload Identity to a given Kubernetes ServiceAccount -- generic object storage for whatever workload needs it (Default: `false`)"
  type        = bool
  default     = false
}

variable "workload_storage_ksa_namespace" {
  description = "Namespace of the Kubernetes ServiceAccount to bind the storage GSA to"
  type        = string
  default     = ""
}

variable "workload_storage_ksa_name" {
  description = "Names of the Kubernetes ServiceAccounts to bind the storage GSA to -- every workload that touches the bucket directly needs its own binding (e.g. Agent Substrate's atelet AND ate-api-server, which independently manages golden-snapshot Tags)"
  type        = list(string)
  default     = []
}

# -- Tagging and labeling

variable "owner" {
  description = "Name of the maintainer of the GKE cluster"
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

variable "extra_labels" {
  description = "Labels used for the GKE resources"
  type        = map(string)
  default     = {}
}

variable "extra_tags" {
  description = "Tags used for the GKE resources"
  type        = list(string)
  default     = []
}

variable "gke_restrict_control_plane_access" {
  description = "Restrict the control plane's public endpoint to the applying workstation's own IP (Default: `false` -- open to the internet, matching this demo tool's convention of gating access on the application-facing LoadBalancers instead, not the cluster's own admin API)"
  type        = bool
  default     = false
}
