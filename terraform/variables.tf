# variables.tf
# The defaults are the COMPLIANT values.
# tests/noncompliant.auto.tfvars overrides them with bad values to show Sentinel blocking the plan.

variable "region" {
  description = "AWS region. eu-west-1 is the AWS Dublin region."
  type        = string
  default     = "eu-west-1"
}

variable "name_prefix" {
  description = "Prefix used in resource names"
  type        = string
  default     = "atul00205200"
}

variable "instance_type" {
  description = "EC2 instance type. Policy only allows t2.micro and t3.micro."
  type        = string
  default     = "t3.micro"
}

variable "imds_http_tokens" {
  description = "required = IMDSv2 only. optional = IMDSv1 still allowed (not compliant)."
  type        = string
  default     = "required"
}

variable "ebs_encrypted" {
  description = "Encrypt the root disk and the data disk"
  type        = bool
  default     = true
}

variable "admin_cidr" {
  description = "Network that is allowed to SSH to the server. Never 0.0.0.0/0."
  type        = string
  default     = "10.10.0.0/16"
}

variable "create_offshore_backup" {
  description = "Creates a backup bucket in backup_region. Only used for the non-compliant test."
  type        = bool
  default     = false
}

variable "backup_region" {
  description = "Region for the offshore backup bucket (non-compliant test only)"
  type        = string
  default     = "eu-west-1"
}
