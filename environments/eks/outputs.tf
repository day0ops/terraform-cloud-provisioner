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

output "eks_dns_zone_id" {
  value       = try(aws_route53_zone.child[0].zone_id, null)
  description = "Route53 child hosted zone ID"
}

output "eks_dns_zone_name" {
  value       = try(aws_route53_zone.child[0].name, null)
  description = "Route53 child hosted zone name"
}

output "eks_dns_nameservers" {
  value       = try(aws_route53_zone.child[0].name_servers, [])
  description = "Nameservers for the child hosted zone"
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
