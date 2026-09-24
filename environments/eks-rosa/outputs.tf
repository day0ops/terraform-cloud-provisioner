output "eks_kubeconfig" {
  value       = join(":", module.eks[*].kubeconfig_path)
  description = "Paths to EKS kubeconfig files"
}

output "eks_kubeconfig_context" {
  value       = [for c in module.eks[*].kubeconfig_context : c]
  description = "EKS kubeconfig context names"
}

output "eks_cluster_name" {
  value       = [for c in module.eks[*].k8s_cluster_name : c]
  description = "EKS cluster names"
}

output "eks_vpc_ids" {
  value       = [for m in module.eks[*] : m.vpc_id]
  description = "VPC IDs for all EKS clusters"
}

output "eks_private_subnet_ids" {
  value       = [for m in module.eks[*] : m.private_subnet_ids]
  description = "Private subnet IDs per EKS cluster (list of lists)"
}

output "eks_worker_security_group_ids" {
  value       = [for m in module.eks[*] : m.worker_security_group_id]
  description = "Worker security group IDs for all EKS clusters"
}

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

output "rosa_aws_load_balancer_controller_role_arns" {
  value       = [for m in module.rosa[*] : m.aws_load_balancer_controller_role_arn]
  description = "IRSA role ARNs for the AWS Load Balancer Controller on all ROSA clusters"
}

output "shared_dns_zone_id" {
  value       = try(aws_route53_zone.child[0].zone_id, null)
  description = "Route53 child hosted zone ID (shared across EKS and ROSA)"
}

output "shared_dns_zone_name" {
  value       = try(aws_route53_zone.child[0].name, null)
  description = "Route53 child hosted zone name (shared across EKS and ROSA)"
}

output "shared_dns_nameservers" {
  value       = try(aws_route53_zone.child[0].name_servers, [])
  description = "Nameservers for the child hosted zone (shared across EKS and ROSA)"
}
