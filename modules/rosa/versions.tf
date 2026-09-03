terraform {
  required_version = ">= 1.5.7"

  required_providers {
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "~> 1.7"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}
