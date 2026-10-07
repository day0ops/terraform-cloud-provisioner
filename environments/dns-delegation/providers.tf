# Route53 is a global service -- region is required by the provider but irrelevant to
# what it does here.
provider "aws" {
  profile = var.aws_profile
  region  = "us-east-1"
}
