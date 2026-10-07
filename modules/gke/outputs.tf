# Kubernetes cluster name
output "k8s_cluster_name" {
  value = local.cluster_name
}

# Kubernetes master version
output "k8s_master_version" {
  value = local.k8s_version
}

# Kubeconfig path
output "kubeconfig_path" {
  value = abspath("${path.module}/output/kubeconfig-gke-${var.gke_cluster_index}")
}

# Kubeconfig context
output "kubeconfig_context" {
  value = local.kubeconfig_context
}

output "workload_storage_bucket" {
  value       = try("gs://${google_storage_bucket.workload_storage[0].name}", null)
  description = "Workload storage bucket URI (gs://...), null if not enabled"
}

output "workload_storage_identity_annotation_key" {
  value       = try(google_service_account.workload_storage[0].email, null) != null ? "iam.gke.io/gcp-service-account" : null
  description = "Kubernetes ServiceAccount annotation key for Workload Identity, null if not enabled"
}

output "workload_storage_identity_annotation_value" {
  value       = try(google_service_account.workload_storage[0].email, null)
  description = "GSA email to annotate the Kubernetes ServiceAccount with, null if not enabled"
}