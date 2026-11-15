# providers.tf
# AWS credentials are NOT stored here. They are set as sensitive
# environment variables in the HCP Terraform workspace.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project    = "terraform-sovereignty"
      Owner      = "L00205200"
      Org        = "ATUL00205200"
      ManagedBy  = "Terraform"
      Compliance = "IE-digital-sovereignty"
    }
  }
}
