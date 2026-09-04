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
  value = abspath("${path.module}/output/kubeconfig-eks-${var.eks_cluster_index}")
}

# Kubeconfig context
output "kubeconfig_context" {
  value = local.kubeconfig_context
}

output "vpc_id" {
  value       = try(aws_vpc.eks_vpc[0].id, null)
  description = "VPC ID for the EKS cluster"
}

output "private_subnet_ids" {
  value       = try(aws_subnet.eks_private_subnet[*].id, [])
  description = "Private subnet IDs for AgentCore gateway placement"
}

output "public_subnet_ids" {
  value       = try(aws_subnet.eks_public_subnet[*].id, [])
  description = "Public subnet IDs (worker nodes and directly SSH-reachable instances live here)"
}

output "worker_security_group_id" {
  value       = try(aws_security_group.eks_worker_sec_group[0].id, null)
  description = "Worker node security group ID"
}

output "aws_load_balancer_controller_role_arn" {
  value       = try(aws_iam_role.aws_load_balancer_controller_role[0].arn, null)
  description = "IRSA role ARN for the AWS Load Balancer Controller service account"
}
