module "defaults" {
  source = "../../modules/defaults"
}

locals {
  dns_enabled      = var.enable_dns
  dns_child_domain = local.dns_enabled ? "${var.dns_child_zone_name}.${var.dns_parent_domain}" : ""
}

# One shared child zone for the entire environment (not per-cloud) - both the EKS
# and ROSA clusters' addons (external-dns, cert-manager) resolve against it.
resource "aws_route53_zone" "child" {
  count         = local.dns_enabled ? 1 : 0
  name          = local.dns_child_domain
  force_destroy = true
  tags = {
    "managed-by" = "terraform"
    "created-by" = var.owner
    "team"       = var.team
    "purpose"    = var.purpose
    "provider"   = "eks-rosa"
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
}

module "rosa" {
  source = "../../modules/rosa"
  count  = var.rosa_cluster_count

  # Shares the "aws" provider (and region, var.eks_region) configured above
  # for EKS: this environment only declares one (unaliased) aws provider, so
  # both clusters land in the same region. rosa_region here only drives the
  # module's own cleanup script's `--region` flag, not actual placement, so
  # it must match the provider's real region.
  rosa_region                   = var.eks_region
  rosa_cluster_name             = var.rosa_cluster_name
  rosa_cluster_index            = count.index + 1
  rosa_openshift_version        = var.rosa_openshift_version
  rosa_compute_machine_type     = var.rosa_compute_machine_type
  rosa_replicas                 = var.rosa_replicas
  rosa_availability_zones_count = var.rosa_availability_zones_count

  owner   = var.owner
  team    = var.team
  purpose = var.purpose
}
