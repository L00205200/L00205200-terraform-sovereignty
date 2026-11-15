# Test scenarios – ATUL00205200 (L00205200)

Two ways of testing:
- **Mock tests:** `cd sentinel` then `sentinel test -verbose` (runs locally and in GitHub Actions). Test files are in `sentinel/test/<policy>/`, mock data in `sentinel/testdata/`.
- **Real plan tests:** run in HCP Terraform with real AWS credentials (plan only, nothing is created).

## A. Sentinel mock tests

| ID | Policy | Test file | Mock used | Expected |
|---|---|---|---|---|
| M01 | sovereignty | test/sovereignty/pass.hcl | mock-tfplan-pass | main = true |
| M02 | sovereignty | test/sovereignty/fail.hcl | mock-tfplan-fail (us-east-1, offshore bucket, no DataResidency, replication) | main = false |
| M03 | supply_chain | test/supply_chain/pass.hcl | mock-tfconfig-pass | main = true |
| M04 | supply_chain | test/supply_chain/fail.hcl | mock-tfconfig-fail (~> 6.0, unknown provider, git module, unpinned module) | main = false |
| M05 | ec2_instance | test/ec2_instance/pass.hcl | mock-tfplan-pass | main = true |
| M06 | ec2_instance | test/ec2_instance/fail.hcl | mock-tfplan-fail (t3.large) | main = false |
| M07 | encryption | test/encryption/pass.hcl | mock-tfplan-pass | main = true |
| M08 | encryption | test/encryption/fail.hcl | mock-tfplan-fail (root disk + EBS volume not encrypted, http_tokens optional) | main = false |
| M09 | network | test/network/pass.hcl | mock-tfplan-pass | main = true |
| M10 | network | test/network/fail.hcl | mock-tfplan-fail (SSH + 8080 open to 0.0.0.0/0) | main = false |
| M11 | compliance_all | test/compliance_all/pass.hcl | mock-tfplan-pass + mock-tfconfig-pass | main = true |
| M12 | compliance_all | test/compliance_all/fail.hcl | mock-tfplan-fail + mock-tfconfig-fail (every rule broken) | main = false |

## B. Real HCP Terraform plan tests

| ID | Scenario | How | Expected result |
|---|---|---|---|
| P01 | Compliant plan | `terraform plan` with default variables | All 5 HCP policies pass. Apply allowed. |
| P02 | Wrong region | `region = "us-east-1"` | compliance_all FAIL (hard – blocks) |
| P03 | Offshore backup bucket | `create_offshore_backup = true`, `backup_region = "us-east-1"` | compliance_all FAIL (hard) – aws_s3_bucket.offshore_backup[0] in us-east-1, missing DataResidency |
| P04 | Big instance | `instance_type = "t3.large"` | ec2_instance FAIL (advisory – warning only, does not block) |
| P05 | IMDSv1 allowed | `imds_http_tokens = "optional"` | compliance_all FAIL (hard) + encryption FAIL (advisory) |
| P06 | No encryption | `ebs_encrypted = false` | compliance_all FAIL (hard) + encryption FAIL (advisory) |
| P07 | SSH open to world | `admin_cidr = "0.0.0.0/0"` | compliance_all FAIL (hard) + network FAIL (advisory) |
| P08 | Provider not pinned | change `version = "6.63.0"` to `"~> 6.0"` in versions.tf (optional extra test) | compliance_all FAIL (hard) + supply_chain FAIL (advisory) |

P02 – P07 are all done in one run with `tests/noncompliant.auto.tfvars` (copy it into `terraform/`, run plan, then delete it).
P08 is optional: edit, run plan, take a screenshot, then undo the change.
