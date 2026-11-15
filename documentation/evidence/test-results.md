# Test results and evidence – ATUL00205200 (L00205200)

Date tested: 14 November 2026
Terraform version: 1.17.1 Sentinel CLI version: v0.40.0 AWS provider: 6.63.0
HCP Terraform: organisation `ATUL00205200`, workspace `sovereignty-ie`, policy set `atul00205200-policies`

## Summary

| Test | Expected | Actual |
|---|---|---|
| Sentinel mock tests (12 tests, 6 policy files) | all PASS | ✅ all PASS |
| Compliant plan in HCP Terraform | all 5 policies pass, apply allowed | ✅ 5 of 5 passed |
| Non-compliant plan in HCP Terraform | `compliance_all` fails, run blocked | ✅ hard failed – run blocked |
| Apply + destroy of the compliant plan | resources created in eu-west-1, then removed | ✅ 17 added / 17 destroyed |

## 1. Sentinel mock tests (local)

Command:
```
cd C:\GitHub\L00205200-terraform-sovereignty\sentinel
sentinel test -verbose
```

Result: **12 tests passed** (a `pass.hcl` and a `fail.hcl` for each of the 6 policy files). A `fail.hcl` showing PASS means the policy correctly returned `false` for the bad mock.

Full output: [`sentinel-test-output.txt`](sentinel-test-output.txt)

Output (key parts):
```
PASS - supply_chain.sentinel
  PASS - test\supply_chain\fail.hcl
    logs:
      FAIL: provider aws version is '~> 6.0' - approved: ["6.63.0"]
      FAIL: provider awsplus comes from registry.terraform.io/randomdev/awsplus - not an approved source
      FAIL: module vpc source git::https://github.com/random-user/terraform-vpc.git is not a trusted module source
      FAIL: module server source terraform-aws-modules/ec2-instance/aws is not a trusted module source
  PASS - test\supply_chain\pass.hcl
PASS - encryption.sentinel
  PASS - test\encryption\fail.hcl
    logs:
      FAIL: aws_instance.app root disk is not encrypted
      FAIL: aws_ebs_volume.data EBS volume is not encrypted
      FAIL: aws_instance.app http_tokens is optional - IMDSv2 (required) is mandatory
  PASS - test\encryption\pass.hcl
PASS - sovereignty.sentinel
  PASS - test\sovereignty\fail.hcl
    logs:
      FAIL: var.region is us-east-1 - approved regions: ["eu-west-1"]
      FAIL: aws_instance.app is in region us-east-1 - outside Ireland
      FAIL: aws_ebs_volume.data is in region us-east-1 - outside Ireland
      FAIL: aws_s3_bucket.offshore_backup[0] is in region us-east-1 - outside Ireland
      FAIL: aws_s3_bucket_replication_configuration.records is in region us-east-1 - outside Ireland
      FAIL: aws_security_group.app is in region us-east-1 - outside Ireland
      FAIL: aws_instance.app stores data but DataClassification is missing
      FAIL: aws_ebs_volume.data holds sensitive data but DataResidency is missing (must be IE)
      FAIL: aws_s3_bucket.offshore_backup[0] holds sensitive data but DataResidency is missing (must be IE)
      FAIL: aws_s3_bucket_replication_configuration.records copies data to another location - aws_s3_bucket_replication_configuration is not allowed
  PASS - test\sovereignty\pass.hcl
PASS - ec2_instance.sentinel
  PASS - test\ec2_instance\fail.hcl
    logs:
      FAIL: aws_instance.app instance type t3.large is not approved: ["t2.micro" "t3.micro"]
  PASS - test\ec2_instance\pass.hcl
PASS - network.sentinel
  PASS - test\network\fail.hcl
    logs:
      FAIL: aws_security_group.app allows SSH (22) from the whole internet ["0.0.0.0/0"]
      FAIL: aws_security_group.app opens ports 22 - 22 protocol tcp to the whole internet - only 80/443 allowed
      FAIL: aws_security_group.app opens ports 8080 - 8080 protocol tcp to the whole internet - only 80/443 allowed
  PASS - test\network\pass.hcl
PASS - compliance_all.sentinel
  PASS - test\compliance_all\fail.hcl
    logs:
      FAIL [sovereignty]: var.region is us-east-1 - approved regions: ["eu-west-1"]
      FAIL [sovereignty]: ... (10 sovereignty messages, same as above)
      FAIL [supply_chain]: provider aws version is '~> 6.0' - approved: ["6.63.0"]
      FAIL [supply_chain]: ... (4 supply chain messages, same as above)
      FAIL [encryption]: aws_instance.app root disk is not encrypted
      FAIL [encryption]: aws_ebs_volume.data EBS volume is not encrypted
      FAIL [imdsv2]: aws_instance.app http_tokens is optional - IMDSv2 (required) is mandatory
      FAIL [network]: aws_security_group.app allows SSH (22) from the whole internet ["0.0.0.0/0"]
      FAIL [network]: ... (2 more network messages)
  PASS - test\compliance_all\pass.hcl
    trace: sovereignty_ok = true, supply_chain_ok = true, encryption_ok = true, imdsv2_ok = true, network_ok = true
6 tests completed in 10.4759ms
```

Screenshot: `screenshots/01-sentinel-test-local.png`

## 2. Sentinel mock tests (GitHub Actions)

Link to the workflow run: https://github.com/L00205200/L00205200-terraform-sovereignty/actions/runs/43709548251

Screenshot: `screenshots/02-github-actions-green.png`

## 3. Compliant plan in HCP Terraform (all policies pass)

Command (Windows Command Prompt):
```
cd C:\GitHub\L00205200-terraform-sovereignty\terraform
terraform plan -no-color > tfplan 2>&1
```
Full output: [`terraform/tfplan`](../../terraform/tfplan)
Run: https://app.terraform.io/app/ATUL00205200/sovereignty-ie/runs/run-FUP6o7Wzw9ZsXHz7
Logs: [`hcp-compliant-run-logs.txt`](hcp-compliant-run-logs.txt)

**Plan:** `17 to add, 0 to change, 0 to destroy` – every resource in `eu-west-1`, `t3.micro`, disks `encrypted = true`, `http_tokens = "required"`, SSH only from `10.10.0.0/16`, sensitive data tagged `DataResidency = IE`.

**Sentinel Result: true** – "all Sentinel policies passed and the protected behavior is allowed. 5 policies evaluated."

| Policy | Enforcement | Result | Rules |
|---|---|---|---|
| compliance_all | hard-mandatory | ✅ pass | sovereignty_ok, supply_chain_ok, encryption_ok, imdsv2_ok, network_ok = true |
| supply_chain | advisory | ✅ pass | providers_approved_and_pinned, modules_trusted_and_pinned = true |
| encryption | advisory | ✅ pass | instance_disks_encrypted, ebs_volumes_encrypted, imdsv2_required = true |
| network | advisory | ✅ pass | no_public_ssh, only_web_ports_public = true |
| ec2_instance | advisory | ✅ pass | approved_instance_type = true |

Screenshots:
- `screenshots/00-hcp-policy-set.png` – policy set `atul00205200-policies` with the 5 policies, scoped to `sovereignty-ie`
- `screenshots/03-hcp-compliant-run-overview.png` – run page: "Policy checks 5 of 5 passed", +17 resources, "Planned and finished"
- `screenshots/04-hcp-compliant-policy-details.png` – all 5 policies passed

## 4. Non-compliant plan in HCP Terraform (blocked)

Command (Windows Command Prompt, inside terraform folder):
```
copy ..\tests\noncompliant.auto.tfvars .
terraform plan -no-color > ..\documentation\evidence\tfplan-noncompliant.txt 2>&1
del noncompliant.auto.tfvars
```
Values used (`tests/noncompliant.auto.tfvars`): `region = "us-east-1"`, `instance_type = "t3.large"`, `imds_http_tokens = "optional"`, `ebs_encrypted = false`, `admin_cidr = "0.0.0.0/0"`, `create_offshore_backup = true`, `backup_region = "us-east-1"`.

Full output: [`tfplan-noncompliant.txt`](tfplan-noncompliant.txt)
Run: https://app.terraform.io/app/ATUL00205200/sovereignty-ie/runs/run-ks4y1x6qK3xiMX9Z
Logs: [`hcp-noncompliant-run-logs.txt`](hcp-noncompliant-run-logs.txt)

**Plan:** `18 to add` (17 + `aws_s3_bucket.offshore_backup[0]`) – all in `us-east-1`.

**Sentinel Result: false** → **`Error: Organization Policy Check hard failed.`** The run was blocked and could not be applied.

| Policy | Enforcement | Result | FAIL messages (from output) |
|---|---|---|---|
| compliance_all | hard-mandatory | ❌ fail – **run BLOCKED** | 25 messages: `[sovereignty]` var.region is us-east-1; 19 resources in us-east-1 (incl. aws_s3_bucket.offshore_backup[0], aws_instance.app, aws_ebs_volume.data, module.vpc.aws_vpc.this[0]); offshore_backup holds sensitive data but DataResidency is missing. `[encryption]` root disk not encrypted; EBS volume not encrypted. `[imdsv2]` http_tokens is optional. `[network]` SSH (22) open to 0.0.0.0/0 |
| encryption | advisory | ❌ fail (warning) | root disk not encrypted; EBS volume not encrypted; http_tokens is optional |
| network | advisory | ❌ fail (warning) | aws_security_group.app allows SSH (22) from the whole internet ["0.0.0.0/0"] |
| ec2_instance | advisory | ❌ fail (warning) | instance type t3.large is not approved |
| supply_chain | advisory | ✅ pass | providers and modules were not changed in this test |

Note: HCP printed the port as `22.000000 - 22.000000` because it handles numbers as decimals. The local Sentinel CLI prints `22 - 22`.

Screenshots:
- `screenshots/05-hcp-noncompliant-run-blocked.png` – run page showing "Policy check hard failed" and no Apply button
- `screenshots/06-hcp-noncompliant-policy-details.png` – compliance_all expanded with the FAIL messages

## 5. (Optional) Supply chain fail – provider not pinned

Not done. The supply chain rules are tested with the mock data instead (section 1: `supply_chain` and `compliance_all` fail tests).

## 6. Apply and destroy of the compliant plan

Command (Windows Command Prompt, terraform folder):
```
terraform apply
terraform destroy
```

- `terraform apply`: the Sentinel policy check passed again (5 of 5), and 17 resources were created in **eu-west-1**. Result: `Apply complete! Resources: 17 added, 0 changed, 0 destroyed.`
- Checked in the AWS console (region Europe (Ireland)): EC2 instance `atul00205200-app` (t3.micro), EBS volume `atul00205200-data` (encrypted), S3 bucket `atul00205200-records-...`
- `terraform destroy`: removed everything. Result: `Destroy complete! Resources: 17 destroyed.`

Screenshots:
- `screenshots/07-hcp-apply-success.png` – "Apply complete! Resources: 17 added"
- `screenshots/08-aws-console-eu-west-1.png` – EC2 resources in Europe (Ireland)
- `screenshots/09-destroy-complete.png` – "Destroy complete! Resources: 17 destroyed."

## 7. HCP Sentinel mocks

Downloaded from the compliant run and saved to `hcp-mocks/`: ☐ yes ☐ not available

## 8. What I learned / problems I hit


- My first plan failed with "No valid credential sources found". I had typed the AWS access key into the **Key** box of the workspace variable instead of the **Value** box. The keys must be environment variables called `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
- HCP Terraform Free only allowed one hard-mandatory policy in my organisation. Soft-mandatory was not available, and after that only advisory was left. I had to change my design and combine every blocking rule into one policy, `compliance_all`.
- When I pasted the policies into HCP, I put the encryption code into the `network` policy by mistake. I only noticed because the plan output showed encryption rules under the network policy. The policy descriptions and rule names in the output helped me spot it.
- The mock tests with `sentinel test` let me check the policies before using HCP, without creating anything in AWS.
- Checking the region of every resource matters. In the non-compliant run, the offshore backup bucket used its own `region` setting, and the policy still caught it.
