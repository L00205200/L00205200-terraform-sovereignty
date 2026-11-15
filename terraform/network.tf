# network.tf
# VPC comes from a trusted public module with a pinned version (supply chain control).
# Only private subnets and no NAT gateway, so there is no extra cost.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name            = "${var.name_prefix}-vpc"
  cidr            = "10.10.0.0/16"
  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
}

resource "aws_security_group" "app" {
  name_prefix = "${var.name_prefix}-app-"
  description = "App server - SSH only from the admin network"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from admin network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "HTTPS inside the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    description = "HTTPS out"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-app-sg"
  }
}
