terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Was pinned to ~> 6.28.0 (that one minor only); the ROSA HCP module's
      # own dependency tree needs >= 6.44.0, and the two combine in the
      # eks-rosa environment, so widen rather than pin narrowly.
      version = ">= 6.28.0, < 7.0.0"
    }
  }
}
