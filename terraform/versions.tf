# versions.tf
# Terraform version, HCP Terraform connection and the providers this project is allowed to use.
# The AWS provider is pinned to one exact version (supply chain control).

terraform {
  required_version = ">= 1.9.0"

  # HCP Terraform (free) - runs the plan remotely and runs the Sentinel policies
  cloud {
    organization = "ATUL00205200"

    workspaces {
      name = "sovereignty-ie"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.63.0"
    }
  }
}
