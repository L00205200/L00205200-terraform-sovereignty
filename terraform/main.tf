# main.tf
# A small "records system" for ATUL00205200:
#   - one EC2 app server (free tier size, private subnet)
#   - one extra EBS disk that holds sensitive data
#   - one S3 bucket that holds sensitive records
# Every resource that stores data has a DataClassification tag.
# Sensitive data also has DataResidency = IE.

# Latest Amazon Linux 2023 AMI for the selected region
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = false

  # IMDSv2 - stops SSRF attacks stealing the instance role credentials
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.imds_http_tokens
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = var.ebs_encrypted
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name               = "${var.name_prefix}-app"
    DataClassification = "internal"
  }
}

# Extra disk for the app data (sensitive)
resource "aws_ebs_volume" "data" {
  availability_zone = "${var.region}a"
  size              = 1
  type              = "gp3"
  encrypted         = var.ebs_encrypted

  tags = {
    Name               = "${var.name_prefix}-data"
    DataClassification = "sensitive"
    DataResidency      = "IE"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.app.id
}

# S3 bucket for sensitive records
resource "aws_s3_bucket" "records" {
  bucket_prefix = "${var.name_prefix}-records-"
  force_destroy = true

  tags = {
    Name               = "${var.name_prefix}-records"
    DataClassification = "sensitive"
    DataResidency      = "IE"
  }
}

resource "aws_s3_bucket_public_access_block" "records" {
  bucket                  = aws_s3_bucket.records.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "records" {
  bucket = aws_s3_bucket.records.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# NON-COMPLIANT TEST ONLY (count = 0 normally).
# AWS provider v6 lets you set "region" on a single resource, so a
# backup copy could go to another region even when the provider is in Dublin.
# The sovereignty policy checks the region of every resource to catch this.
resource "aws_s3_bucket" "offshore_backup" {
  count = var.create_offshore_backup ? 1 : 0

  region        = var.backup_region
  bucket_prefix = "${var.name_prefix}-backup-"
  force_destroy = true

  tags = {
    Name               = "${var.name_prefix}-backup"
    DataClassification = "sensitive"
  }
}
