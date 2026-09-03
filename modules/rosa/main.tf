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

# HCP's control-plane-operator creates its own VPC-endpoint security group
# directly in AWS (outside this module, via cross-account OIDC role
# assumption) for private connectivity to the control plane. Its own cleanup
# doesn't reliably remove that security group when the cluster is deleted,
# which then blocks this VPC's own deletion with a DependencyViolation.
# Sweep leftover non-default security groups before the VPC destroy runs,
# retrying since the operator's own cleanup can lag by a few minutes.
resource "null_resource" "cleanup_orphaned_security_groups" {
  triggers = {
    vpc_id = module.vpc.vpc_id
    region = var.rosa_region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -euo pipefail
      region="${self.triggers.region}"
      vpc_id="${self.triggers.vpc_id}"
      # AWS's own dependency check for security groups covers two distinct
      # cases here: a still-attached ENI from the operator's VPC endpoint
      # (found and cleared directly below), and a backend propagation lag
      # where the ENI is already gone from the API but the security-group
      # dependency check hasn't caught up yet (needs a retry window rather
      # than anything to actively clean up). 30 attempts * 20s covers both.
      for attempt in $(seq 1 30); do
        sgs=$(aws ec2 describe-security-groups \
          --region "$region" \
          --filters "Name=vpc-id,Values=$vpc_id" \
          --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
          --output text)
        if [ -z "$sgs" ]; then
          exit 0
        fi
        for sg in $sgs; do
          enis=$(aws ec2 describe-network-interfaces \
            --region "$region" \
            --filters "Name=group-id,Values=$sg" "Name=status,Values=available" \
            --query 'NetworkInterfaces[].NetworkInterfaceId' \
            --output text)
          for eni in $enis; do
            aws ec2 delete-network-interface --region "$region" --network-interface-id "$eni" || true
          done
          aws ec2 delete-security-group --region "$region" --group-id "$sg" || true
        done
        sleep 20
      done
    EOT
  }
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
    # Credentials travel via the environment, not the command string: on
    # failure Terraform echoes the literal command (with $VARS unexpanded)
    # in the error output, but would print an interpolated password verbatim.
    environment = {
      OC_USERNAME = module.hcp.cluster_admin_username
      OC_PASSWORD = module.hcp.cluster_admin_password
    }
    command = <<-EOT
      set -euo pipefail
      mkdir -p ${path.module}/output
      # The HCP API load balancer can intermittently time out right after
      # cluster creation while its target group is still stabilizing, so
      # retry a few times rather than failing the whole apply on one blip.
      for attempt in 1 2 3 4 5; do
        if oc login ${module.hcp.cluster_api_url} \
          --username="$OC_USERNAME" \
          --password="$OC_PASSWORD" \
          --insecure-skip-tls-verify=true \
          --kubeconfig=${path.module}/output/kubeconfig-rosa-${var.rosa_cluster_index}; then
          break
        fi
        if [ "$attempt" = 5 ]; then
          exit 1
        fi
        sleep 20
      done
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
