output "rosa_kubeconfig" {
  value       = join(":", module.rosa[*].kubeconfig_path)
  description = "Paths to ROSA kubeconfig files"
}

output "rosa_kubeconfig_context" {
  value       = [for c in module.rosa[*].kubeconfig_context : c]
  description = "ROSA kubeconfig context names"
}

output "rosa_cluster_name" {
  value       = [for c in module.rosa[*].k8s_cluster_name : c]
  description = "ROSA cluster names"
}

output "rosa_vpc_ids" {
  value       = [for m in module.rosa[*] : m.vpc_id]
  description = "VPC IDs for all ROSA clusters"
}

output "rosa_private_subnet_ids" {
  value       = [for m in module.rosa[*] : m.private_subnet_ids]
  description = "Private subnet IDs per ROSA cluster (list of lists)"
}
