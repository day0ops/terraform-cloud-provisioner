module "defaults" {
  source = "../../modules/defaults"
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
