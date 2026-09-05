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

output "eks_nat_gateway_public_ips" {
  value       = [for m in module.eks[*] : m.nat_gateway_public_ip]
  description = "NAT Gateway public IPs for all EKS clusters (stable egress source when eks_private_nodes is true)"
}

output "eks_aws_load_balancer_controller_role_arns" {
  value       = [for m in module.eks[*] : m.aws_load_balancer_controller_role_arn]
  description = "AWS Load Balancer Controller IRSA role ARNs for all EKS clusters"
}

output "eks_vm_public_ip" {
  value       = try(module.vm_workload[0].vm_public_ip, null)
  description = "Public IP address of the VM workload instance"
}

output "eks_vm_private_ip" {
  value       = try(module.vm_workload[0].vm_private_ip, null)
  description = "Private IP address of the VM workload instance"
}

output "eks_vm_instance_id" {
  value       = try(module.vm_workload[0].vm_instance_id, null)
  description = "Instance ID of the VM workload"
}

output "eks_vm_security_group_id" {
  value       = try(module.vm_workload[0].vm_security_group_id, null)
  description = "Security group ID for the VM workload"
}

output "eks_vm_ssh_private_key_path" {
  value       = try(module.vm_workload[0].vm_ssh_private_key_path, null)
  description = "Local filesystem path to the generated SSH private key for the VM workload"
}
