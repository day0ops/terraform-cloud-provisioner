provider "aws" {
  region  = var.eks_region
  profile = var.aws_profile
}

# Auth via RHCS_CLIENT_ID / RHCS_CLIENT_SECRET env vars (service account,
# Red Hat's recommended auth method). See docs/index.md in
# terraform-redhat/terraform-provider-rhcs for the legacy RHCS_TOKEN
# alternative.
provider "rhcs" {}
