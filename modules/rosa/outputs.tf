# Kubernetes cluster name
output "k8s_cluster_name" {
  value = var.rosa_cluster_name
}

# Kubeconfig path
output "kubeconfig_path" {
  value      = abspath("${path.module}/output/kubeconfig-rosa-${var.rosa_cluster_index}")
  depends_on = [null_resource.kubeconfig]
}

# Kubeconfig context
output "kubeconfig_context" {
  value = trimspace(data.local_file.kubeconfig_context.content)
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID for the ROSA cluster"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs for the ROSA cluster's VPC"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnets
  description = "Public subnet IDs for the ROSA cluster's VPC"
}
