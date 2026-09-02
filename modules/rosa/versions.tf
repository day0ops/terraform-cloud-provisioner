terraform {
  required_version = ">= 1.5.7"

  required_providers {
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "~> 1.7"
    }
  }
}
