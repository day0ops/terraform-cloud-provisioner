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

# -- AWS Load Balancer Controller (IRSA)
#
# ROSA's own OIDC provider (created internally by the rhcs-hcp module via create_oidc =
# true) isn't exposed as a Terraform-owned resource we can reference directly - only its
# issuer URL (module.hcp.oidc_endpoint_url) is. Look it up via data source instead of
# owning it, unlike EKS's module which creates and owns aws_iam_openid_connect_provider
# directly.
#
# oidc_endpoint_url itself is scheme-less (e.g. "oidc.op1.openshiftapps.com/<id>") - that's
# the correct, expected form for the :aud/:sub condition keys below, but this data source's
# url argument needs a real URL to parse a host out of, hence the https:// prepended here
# only.
data "aws_iam_openid_connect_provider" "rosa_oidc" {
  url = "https://${module.hcp.oidc_endpoint_url}"
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.rosa_oidc.arn]
    }
    condition {
      test     = "StringEquals"
      # ROSA's own IRSA-equivalent webhook (confirmed live via a running pod's
      # projected token volume) issues tokens with audience "openshift", not AWS's
      # own EKS convention "sts.amazonaws.com" - it matches Red Hat's cloud-credential-
      # operator's own STS trust policy convention for cluster operators, and workloads
      # riding the same mechanism must match it too.
      variable = "${replace(module.hcp.oidc_endpoint_url, "https://", "")}:aud"
      values   = ["openshift"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.hcp.oidc_endpoint_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:aws-load-balancer-controller:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller_iam_policy" {
  name = "${local.name_prefix}-aws-load-balancer-controller-policy"
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "iam:CreateServiceLinkedRole",
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeAddresses",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeInternetGateways",
            "ec2:DescribeVpcs",
            "ec2:DescribeVpcPeeringConnections",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeInstances",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeTags",
            "ec2:GetCoipPoolUsage",
            "ec2:DescribeCoipPools",
            "ec2:GetSecurityGroupsForVpc",
            "ec2:DescribeIpamPools",
            "ec2:DescribeRouteTables",
            "elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:DescribeLoadBalancerAttributes",
            "elasticloadbalancing:DescribeListeners",
            "elasticloadbalancing:DescribeListenerCertificates",
            "elasticloadbalancing:DescribeSSLPolicies",
            "elasticloadbalancing:DescribeRules",
            "elasticloadbalancing:DescribeTargetGroups",
            "elasticloadbalancing:DescribeTargetGroupAttributes",
            "elasticloadbalancing:DescribeTargetHealth",
            "elasticloadbalancing:DescribeTags",
            "elasticloadbalancing:DescribeTrustStores",
            "elasticloadbalancing:DescribeListenerAttributes",
            "elasticloadbalancing:DescribeCapacityReservation",
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "cognito-idp:DescribeUserPoolClient",
            "acm:ListCertificates",
            "acm:DescribeCertificate",
            "iam:ListServerCertificates",
            "iam:GetServerCertificate",
            "waf-regional:GetWebACL",
            "waf-regional:GetWebACLForResource",
            "waf-regional:AssociateWebACL",
            "waf-regional:DisassociateWebACL",
            "wafv2:GetWebACL",
            "wafv2:GetWebACLForResource",
            "wafv2:AssociateWebACL",
            "wafv2:DisassociateWebACL",
            "shield:GetSubscriptionState",
            "shield:DescribeProtection",
            "shield:CreateProtection",
            "shield:DeleteProtection",
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress",
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateSecurityGroup",
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateTags",
          ]
          Resource = "arn:aws:ec2:*:*:security-group/*"
          Condition = {
            StringEquals = {
              "ec2:CreateAction" = "CreateSecurityGroup"
            }
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateTags",
            "ec2:DeleteTags",
          ]
          Resource = "arn:aws:ec2:*:*:security-group/*"
          Condition = {
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
              "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress",
            "ec2:DeleteSecurityGroup",
          ]
          Resource = "*"
          Condition = {
            Null = {
              "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:CreateTargetGroup",
          ]
          Resource = "*"
          Condition = {
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:DeleteListener",
            "elasticloadbalancing:CreateRule",
            "elasticloadbalancing:DeleteRule",
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags",
          ]
          Resource = [
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
          ]
          Condition = {
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
              "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags",
          ]
          Resource = [
            "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:ModifyLoadBalancerAttributes",
            "elasticloadbalancing:SetIpAddressType",
            "elasticloadbalancing:SetSecurityGroups",
            "elasticloadbalancing:SetSubnets",
            "elasticloadbalancing:DeleteLoadBalancer",
            "elasticloadbalancing:ModifyTargetGroup",
            "elasticloadbalancing:ModifyTargetGroupAttributes",
            "elasticloadbalancing:DeleteTargetGroup",
            "elasticloadbalancing:ModifyListenerAttributes",
            "elasticloadbalancing:ModifyCapacityReservation",
            "elasticloadbalancing:ModifyIpPools",
          ]
          Resource = "*"
          Condition = {
            Null = {
              "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:AddTags",
          ]
          Resource = [
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
          ]
          Condition = {
            StringEquals = {
              "elasticloadbalancing:CreateAction" = [
                "CreateTargetGroup",
                "CreateLoadBalancer",
              ]
            }
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:RegisterTargets",
            "elasticloadbalancing:DeregisterTargets",
          ]
          Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:SetWebAcl",
            "elasticloadbalancing:ModifyListener",
            "elasticloadbalancing:AddListenerCertificates",
            "elasticloadbalancing:RemoveListenerCertificates",
            "elasticloadbalancing:ModifyRule",
            "elasticloadbalancing:SetRulePriorities",
          ]
          Resource = "*"
        },
      ]
    }
  )
}

resource "aws_iam_role" "aws_load_balancer_controller_role" {
  name               = "${local.name_prefix}-aws-load-balancer-controller-role"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller_iam_policy.arn
  role       = aws_iam_role.aws_load_balancer_controller_role.name
}

# -- external-dns (IRSA)
#
# Without this, external-dns falls through the AWS SDK's default credential chain to
# EC2 IMDS, which ROSA worker nodes don't expose to pods - confirmed live via "no EC2
# IMDS role found... connection refused" in its logs. Reuses the same OIDC provider
# lookup as the AWS Load Balancer Controller above.
data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.rosa_oidc.arn]
    }
    condition {
      test     = "StringEquals"
      # ROSA's own IRSA-equivalent webhook (confirmed live via a running pod's
      # projected token volume) issues tokens with audience "openshift", not AWS's
      # own EKS convention "sts.amazonaws.com" - it matches Red Hat's cloud-credential-
      # operator's own STS trust policy convention for cluster operators, and workloads
      # riding the same mechanism must match it too.
      variable = "${replace(module.hcp.oidc_endpoint_url, "https://", "")}:aud"
      values   = ["openshift"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.hcp.oidc_endpoint_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }
  }
}

# Canonical minimal external-dns policy (see kubernetes-sigs/external-dns's own AWS
# tutorial) - list zones/records account-wide, change records scoped to any zone.
resource "aws_iam_policy" "external_dns_iam_policy" {
  name = "${local.name_prefix}-external-dns-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
        ]
        Resource = ["*"]
      },
    ]
  })
}

resource "aws_iam_role" "external_dns_role" {
  name               = "${local.name_prefix}-external-dns-role"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
}

resource "aws_iam_role_policy_attachment" "external_dns_policy" {
  policy_arn = aws_iam_policy.external_dns_iam_policy.arn
  role       = aws_iam_role.external_dns_role.name
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
