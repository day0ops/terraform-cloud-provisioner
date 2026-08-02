module "defaults" {
  source = "../../modules/defaults"
}

locals {
  dns_enabled      = var.enable_dns
  dns_child_domain = local.dns_enabled ? "${var.dns_child_zone_name}.${var.dns_parent_domain}" : ""
}

# One shared child zone for the entire environment (not per-cluster)
resource "aws_route53_zone" "child" {
  count         = local.dns_enabled ? 1 : 0
  name          = local.dns_child_domain
  force_destroy = true
  tags = {
    "managed-by" = "terraform"
    "created-by" = var.owner
    "team"       = var.team
    "purpose"    = var.purpose
    "provider"   = "eks"
  }
}

resource "aws_route53_record" "child_ns" {
  count   = local.dns_enabled ? 1 : 0
  zone_id = var.dns_parent_zone_id
  name    = local.dns_child_domain
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.child[0].name_servers
}

module "eks" {
  source = "../../modules/eks"
  count  = var.eks_cluster_count

  enable_eks         = true
  aws_profile        = var.aws_profile
  eks_region         = var.eks_region
  eks_cluster_name   = var.eks_cluster_name
  eks_cluster_index  = count.index + 1
  eks_nodes          = var.eks_nodes
  eks_min_nodes      = var.eks_min_nodes
  eks_max_nodes      = var.eks_max_nodes
  eks_node_type      = var.eks_node_type
  eks_subnets        = var.eks_subnets
  kubernetes_version = coalesce(var.kubernetes_version, module.defaults.kubernetes_version)

  owner   = var.owner
  team    = var.team
  purpose = var.purpose

  enable_dns = var.enable_dns
}

# ----------------------------------------------------------------------------------
# VM workload – attaches to the vm_cluster_index'th cluster's VPC
# ----------------------------------------------------------------------------------

module "vm_workload" {
  source = "../../modules/vm-workload"
  count  = var.enable_vm ? 1 : 0

  enable                           = var.enable_vm
  owner                            = var.owner
  prefix_name                      = var.owner
  vpc_id                           = module.eks[var.vm_cluster_index].vpc_id
  subnet_id                        = module.eks[var.vm_cluster_index].public_subnet_ids[0]
  cluster_worker_security_group_id = module.eks[var.vm_cluster_index].worker_security_group_id
  instance_type                    = var.vm_instance_type

  tags = {
    "owner"      = var.owner
    "managed-by" = "terraform"
  }
}
