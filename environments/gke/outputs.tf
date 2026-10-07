output "gke_kubeconfig" {
  value       = join(":", module.gke[*].kubeconfig_path)
  description = "Paths to GKE kubeconfig files"
}

output "gke_kubeconfig_context" {
  value       = [for c in module.gke[*].kubeconfig_context : c]
  description = "GKE kubeconfig context names"
}

output "gke_cluster_name" {
  value       = [for c in module.gke[*].k8s_cluster_name : c]
  description = "GKE cluster names"
}

output "gke_workload_storage_bucket" {
  value       = [for m in module.gke[*] : m.workload_storage_bucket]
  description = "Workload storage bucket URIs, per cluster (null where not enabled)"
}

output "gke_workload_storage_identity_annotation_key" {
  value       = [for m in module.gke[*] : m.workload_storage_identity_annotation_key]
  description = "Workload storage KSA annotation keys, per cluster (null where not enabled)"
}

output "gke_workload_storage_identity_annotation_value" {
  value       = [for m in module.gke[*] : m.workload_storage_identity_annotation_value]
  description = "Workload storage KSA annotation values, per cluster (null where not enabled)"
}

output "gke_dns_zone_id" {
  value       = try(google_dns_managed_zone.child[0].name, null)
  description = "Cloud DNS managed zone resource name (GCP's own zone identifier, distinct from the DNS name itself)"
}

output "gke_dns_zone_name" {
  value       = try(google_dns_managed_zone.child[0].dns_name, null)
  description = "Cloud DNS zone's DNS name (FQDN, trailing dot)"
}

output "gke_dns_nameservers" {
  value       = try(google_dns_managed_zone.child[0].name_servers, [])
  description = "Cloud DNS zone's name servers -- feed these into environments/dns-delegation to create the Route53 NS delegation record in the parent zone"
}
