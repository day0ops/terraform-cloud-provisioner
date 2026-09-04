data "aws_availability_zones" "available" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "random_id" "eks_cluster_name_suffix" {
  byte_length = 4
}

locals {
  name                 = try(trim(format("%v-ipv6-%v", var.owner, random_id.eks_cluster_name_suffix.hex), 20), "")
  kubeconfig_context   = try(format("eks-ipv6-%v", random_id.eks_cluster_name_suffix.hex), "")
  current_k8s_version  = try(var.kubernetes_version, "")
  vpc_cidr             = "10.0.0.0/16"
  zones                = slice(data.aws_availability_zones.available.names, 0, var.max_availability_zones)
  account_id           = data.aws_caller_identity.current.account_id
  cni_ipv6_policy_name = "AmazonEKS_CNI_IPv6_Policy"
}

data "aws_iam_policy" "cni_ipv6_policy" {
  name = local.cni_ipv6_policy_name
}

# ----------------------------------------------------------------------------------
# VPC – dual-stack with IPv6
# ----------------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.zones
  public_subnets  = [for k, v in local.zones : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.zones : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_ipv6                                    = true
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_assign_ipv6_address_on_creation = true
  public_subnet_ipv6_native                      = false
  private_subnet_ipv6_native                     = false
  create_egress_only_igw                         = true
  public_subnet_enable_dns64                     = var.enable_dns64
  private_subnet_enable_dns64                    = var.enable_dns64

  public_subnet_ipv6_prefixes  = var.public_subnet_ipv6_prefixes
  private_subnet_ipv6_prefixes = var.private_subnet_ipv6_prefixes

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = merge(var.tags, {
    "owner"   = var.owner
    "team"    = var.team
    "purpose" = var.purpose
  })
}

# ----------------------------------------------------------------------------------
# EKS – IPv6 cluster with managed node groups
# ----------------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                                     = local.name
  kubernetes_version                       = local.current_k8s_version
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  ip_family                  = "ipv6"
  create_cni_ipv6_iam_policy = false

  create_primary_security_group_tags = true

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  enable_irsa = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = merge(var.tags, {
    "owner"   = var.owner
    "team"    = var.team
    "purpose" = var.purpose
  })

  eks_managed_node_groups = {
    default = {
      name                     = "${local.name}-ng"
      use_name_prefix          = false
      iam_role_use_name_prefix = false

      instance_types = [var.node_type]

      min_size     = var.min_nodes
      max_size     = var.max_nodes
      desired_size = var.nodes
      key_name     = var.ec2_ssh_key

      subnet_ids = module.vpc.private_subnets

      tags = merge(var.tags, {
        Name = "${local.name}-ng"
      })
    }
  }
}

# ----------------------------------------------------------------------------------
# Security groups
# ----------------------------------------------------------------------------------

resource "aws_security_group_rule" "allow_istio_mutation_webhook" {
  count = var.allow_istio_mutation_webhook_sg ? 1 : 0

  type                     = "ingress"
  security_group_id        = module.eks.node_security_group_id
  description              = "Allow Istio mutation webhook (Kubernetes admission controller access)"
  from_port                = 15017
  to_port                  = 15017
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
}

resource "aws_security_group_rule" "ingress_bastion" {
  count = var.enable_bastion_access ? 1 : 0

  type                     = "ingress"
  security_group_id        = module.eks.node_security_group_id
  description              = "Incoming traffic from bastion"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = var.bastion_security_group_id
}

# ----------------------------------------------------------------------------------
# Kubeconfig
# ----------------------------------------------------------------------------------

resource "local_file" "kubeconfig" {
  content = templatefile("${path.module}/files/kubeconfig-template.tpl", {
    context                = local.kubeconfig_context
    endpoint               = module.eks.cluster_endpoint
    cluster_ca_certificate = module.eks.cluster_certificate_authority_data
    cluster_name           = local.name
    region                 = var.region
  })
  filename = "${path.module}/output/kubeconfig-${local.kubeconfig_context}"
}
