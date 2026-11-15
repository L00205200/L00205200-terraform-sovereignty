# NON-COMPLIANT values - for the "failed policy" test only.
# Copy this file into the terraform/ folder, run terraform plan, then DELETE it.
# Never run terraform apply with this file.

region                 = "us-east-1"
instance_type          = "t3.large"
imds_http_tokens       = "optional"
ebs_encrypted          = false
admin_cidr             = "0.0.0.0/0"
create_offshore_backup = true
backup_region          = "us-east-1"
