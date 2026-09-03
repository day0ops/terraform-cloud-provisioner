locals {
  name_prefix          = "${var.rosa_cluster_name}-${var.rosa_cluster_index}"
  account_role_prefix  = "${local.name_prefix}-account"
  operator_role_prefix = "${local.name_prefix}-operator"
}

# Self-contained VPC for this cluster instance, using the rosa-hcp module's own
# vpc submodule rather than a hand-rolled one or the EKS module's — this lets
# ROSA provisioning be verified in isolation. Cross-VPC networking (peering to
# an EKS cluster's VPC) is deliberately out of scope for this module.
module "vpc" {
  source  = "terraform-redhat/rosa-hcp/rhcs//modules/vpc"
  version = "~> 1.7"

  name_prefix              = local.name_prefix
  availability_zones_count = var.rosa_availability_zones_count
}

module "hcp" {
  source  = "terraform-redhat/rosa-hcp/rhcs"
  version = "~> 1.7"

  cluster_name           = var.rosa_cluster_name
  openshift_version      = var.rosa_openshift_version
  machine_cidr           = module.vpc.cidr_block
  aws_subnet_ids         = concat(module.vpc.public_subnets, module.vpc.private_subnets)
  aws_availability_zones = module.vpc.availability_zones
  replicas               = var.rosa_replicas
  compute_machine_type   = var.rosa_compute_machine_type

  create_admin_user        = true
  ec2_metadata_http_tokens = "required"

  create_account_roles  = true
  account_role_prefix   = local.account_role_prefix
  create_oidc           = true
  create_operator_roles = true
  operator_role_prefix  = local.operator_role_prefix
}

# rhcs_cluster_rosa_hcp has no kubeconfig output — materialize one locally via
# `oc login` once the cluster and its admin user are ready, mirroring how
# modules/eks writes its own kubeconfig file. The real current-context name is
# captured to a sidecar file rather than guessed in HCL, since `oc login`'s
# <namespace>/<server>/<user> naming convention isn't a documented contract.
resource "null_resource" "kubeconfig" {
  depends_on = [module.hcp]

  triggers = {
    cluster_id = module.hcp.cluster_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      mkdir -p ${path.module}/output
      oc login ${module.hcp.cluster_api_url} \
        --username=${module.hcp.cluster_admin_username} \
        --password='${module.hcp.cluster_admin_password}' \
        --insecure-skip-tls-verify=true \
        --kubeconfig=${path.module}/output/kubeconfig-rosa-${var.rosa_cluster_index}
      oc config current-context --kubeconfig=${path.module}/output/kubeconfig-rosa-${var.rosa_cluster_index} \
        > ${path.module}/output/kubeconfig-rosa-${var.rosa_cluster_index}.context
    EOT
  }
}

# Read via a data source (not the file() function) so the read is deferred to
# apply time: file() is a pure expression evaluated eagerly during plan, which
# fails because this file doesn't exist yet on a first apply.
data "local_file" "kubeconfig_context" {
  filename   = "${path.module}/output/kubeconfig-rosa-${var.rosa_cluster_index}.context"
  depends_on = [null_resource.kubeconfig]
}
