# Terraform Digital Sovereignty Assignment – ATUL00205200

**Student:** Raju Augustine – L00205200
**Organisation (assignment scenario):** ATUL00205200
**Tools:** Terraform, HashiCorp Sentinel, HCP Terraform (Free), GitHub, GitHub Actions, AWS (my own account)

## 1. What this project is

In this scenario I am the head of IT for ATUL00205200, an Irish organisation. Ireland has signed the Declaration for European Digital Sovereignty (2025), and the Dáil debate on 13 May 2026 said that digital security and resilience will be a key priority during Ireland's EU Council presidency. So I need a way to stop anyone in the organisation deploying cloud infrastructure that breaks our sovereignty or security rules.

My solution is **Policy as Code**. The infrastructure is written in Terraform, and HashiCorp Sentinel policies check every Terraform plan in HCP Terraform **before** `apply`. If a plan breaks a rule, the run is stopped and nothing is created in AWS.

The infrastructure is kept small and free-tier: a VPC with private subnets, one `t3.micro` EC2 server, one extra encrypted EBS disk and one S3 bucket for "sensitive records".

## 2. Repository layout

```
.
├── README.md                          <- this file (design + justification)
├── .github/workflows/terraform-checks.yml   <- CI: fmt, lock file, validate, sentinel test
├── documentation/
│   ├── evidence/
│   │   ├── test-results.md            <- results + screenshots of pass / fail runs
│   │   ├── sentinel-test-output.txt   <- full sentinel test output (12 PASS)
│   │   ├── tfplan-noncompliant.txt    <- plan output of the failed (blocked) run
│   │   ├── hcp-compliant-run-logs.txt / hcp-noncompliant-run-logs.txt  <- HCP run logs
│   │   └── screenshots/               <- 00–09 evidence screenshots
│   └── technical-report/
│       └── technical-report.md        <- 1 page: limitations + recommendations
├── sentinel/
│   ├── sentinel.hcl                   <- policy set + enforcement levels
│   ├── compliance_all.sentinel        <- ALL blocking rules (hard-mandatory)
│   ├── sovereignty.sentinel           <- per-area version (local tests only)
│   ├── supply_chain.sentinel          <- per-area (advisory)
│   ├── encryption.sentinel            <- per-area, incl. IMDSv2 (advisory)
│   ├── network.sentinel               <- per-area (advisory)
│   ├── ec2_instance.sentinel          <- instance type, cost rule (advisory)
│   ├── test/<policy>/pass.hcl, fail.hcl   <- sentinel test cases
│   └── testdata/                      <- pass / fail mock data
├── terraform/
│   ├── .terraform.lock.hcl            <- provider checksums
│   ├── versions.tf  providers.tf  variables.tf  main.tf  network.tf  outputs.tf
│   └── tfplan                         <- plan output of the compliant run
└── tests/
    ├── test-scenarios.md              <- list of what is tested and expected result
    └── noncompliant.auto.tfvars       <- bad values used for the failed run
```

The lecturer's example has a `tests/<policy>` folder for each policy. I moved the Sentinel test cases to `sentinel/test/<policy>/`, because the Sentinel CLI only looks for tests in a `test` folder next to the policy files. `tests/` at the root holds the scenario list and the non-compliant variable file.

## 3. The policies

**HCP Terraform Free limits I had to design around:**
- one policy set with a maximum of **five policies**
- in my organisation only **one** policy could be **hard-mandatory** (the UI showed "You have exceeded the number of hard/soft mandatory policies"), and the rest had to be **advisory**
- a policy set can't be linked straight to GitHub on Free (that needs Standard or Premium), so the code is kept in GitHub and I paste the same code into HCP Terraform

At first I had one policy per area (sovereignty, supply chain, encryption, network, EC2) and wanted most of them hard-mandatory. Because only one could block, a plan in Ireland with SSH open to the world would have passed with only a warning. So I changed the design: **every rule that must block a run is combined into one hard-mandatory policy, `compliance_all`**. The per-area policies still run as advisory, so the HCP run page shows a clear result for each area as well.

| Policy in HCP | What it checks | Enforcement |
|---|---|---|
| `compliance_all` | **All** blocking rules: (A) sovereignty – `var.region` and every resource's region is `eu-west-1`, `DataClassification` tag on data stores, `DataResidency = IE` on sensitive data, no cross-region copy resources; (B) supply chain – approved providers/modules with exact version pins; (C) encryption – EC2 root/extra disks and EBS volumes encrypted; IMDSv2 required; (D) network – no SSH from `0.0.0.0/0` or `::/0`, only single ports 80/443 open to the internet | **hard-mandatory** |
| `supply_chain` | Same supply chain checks as (B) | advisory |
| `encryption` | Same as (C), including IMDSv2 | advisory |
| `network` | Same as (D), covering inline `ingress`, `aws_security_group_rule` and `aws_vpc_security_group_ingress_rule` | advisory |
| `ec2_instance` | Instance type is `t2.micro` or `t3.micro` | advisory |

`sovereignty.sentinel` is still in the repo and has its own tests, but it isn't added to HCP because of the 5-policy limit. Its checks are section A of `compliance_all`.

**Why these enforcement levels:**
- Sovereignty, supply chain, encryption, IMDSv2 and network are legal or security rules, so they must block. With only one hard-mandatory slot, they all go into `compliance_all`, and nobody can override it (overrides are switched off on the policy set).
- **Instance type** is mainly a cost rule, so I left it out of `compliance_all` on purpose and made `ec2_instance` advisory. A `t3.large` shows a warning but isn't blocked. On a paid plan I would make it soft-mandatory, so an admin has to approve it.
- **Trade-off:** the same checks exist in two places (`compliance_all` and the per-area files). If I change a rule, I have to change both. The Sentinel tests for each file help catch it if they get out of step.

Every policy prints a clear `FAIL:` message with the resource address, so the developer can see what to fix straight away in the HCP run output.

## 4. Digital sovereignty design

**Approved region.** I only approve `eu-west-1` because it is the AWS region physically located in Ireland. I check the region in two places:
1. `var.region`, which is what the provider uses.
2. The `region` value of **every resource** in the plan.

The second check matters. From AWS provider v6, a single resource can have its own `region` argument. So a developer could leave the provider in Dublin and still put one S3 bucket in `us-east-1`. My non-compliant test does exactly this with `aws_s3_bucket.offshore_backup`, and the policy catches it.

**Data residency.** Not all data is equal, so every resource that stores data has to be classified (`public`, `internal` or `sensitive`). For `sensitive` data the `DataResidency = IE` tag is required as well. This makes the owner state clearly where the data is meant to live, and it makes the data easy to find in AWS later (tag-based reports, AWS Config rules).

**Replication, backups and admin access.**
- **Replication:** S3 cross-region replication, EBS snapshot copy, AMI copy, DynamoDB global table replicas and RDS backup replication can all quietly send a copy of the data outside Ireland. The policy blocks those resource types completely. If one is really needed, it should go through an exception, not just a change in code.
- **Backups:** backups must stay in `eu-west-1` as well. A backup is still a full copy of the data, and the per-resource region check covers backup buckets too. For disaster recovery, a second EU region (for example `eu-central-1`) could be approved for `internal` data only. I kept it simple and allowed only Ireland.
- **Administrative access:** Sentinel can't control *who* logs in. An admin based in another country, or AWS support staff, could still access the data. That has to be handled with IAM (least privilege, MFA), AWS Organizations SCPs that deny actions outside approved regions, CloudTrail logging, and encryption with keys we control (KMS customer-managed keys). I list this as a limitation.

**How jurisdiction helps sovereignty.** When data is kept physically in Ireland it falls under Irish and EU law (GDPR, NIS2), and Irish regulators can supervise it. Keeping it there also stops data flowing to countries with weaker protection without anyone noticing. But location is not full sovereignty: AWS is a US company, so in theory foreign laws such as the US CLOUD Act can still reach it. This is why AWS launched the separate **AWS European Sovereign Cloud** (generally available in January 2026, first region `eusc-de-east-1` in Brandenburg, Germany), which is run only by EU residents. That region is in Germany, not Ireland, so it would be a trade-off: stronger sovereignty, but not in Irish territory.

## 5. IaC supply chain security design

| Risk | Control in this project |
|---|---|
| Provider from an unknown or fake publisher | `supply_chain.sentinel` only allows `registry.terraform.io/hashicorp/aws` |
| Provider updated to a broken or malicious version | Exact version pin `6.63.0` (checked by Sentinel) |
| Provider binary changed / tampered | `.terraform.lock.hcl` checksums are committed. CI runs `terraform init -lockfile=readonly`, which fails if a checksum doesn't match. Terraform also checks the provider signature from the registry. |
| Module from a random Git repo | Only approved registry modules or local folders allowed |
| Module changed under the same version range | Exact version pin required (`6.6.1`, not `~> 6.0`) |
| CI tool tampered | Sentinel CLI in GitHub Actions is pinned to one version and checked against HashiCorp's SHA256SUMS |

**What Sentinel can't cover alone** (also in the technical report):
- Sentinel can't read `.terraform.lock.hcl`, so provider checksums have to be checked in CI.
- Modules on the public registry are **not signed**. A version number points to a Git tag, and in theory the module owner can move that tag. The safest fix is to copy approved modules into our own private registry, or pin to a Git commit SHA.
- **Nested modules** (modules inside modules) and the code inside a module are not reviewed by my policy. It only trusts the source and version.
- A compromised maintainer account, a compromised Terraform binary or a compromised GitHub Action can't be detected from the plan. My workflow pins actions by tag (`@v4`, `@v3`). Pinning to a full commit SHA would be safer.
- Who approved the code change is a GitHub question (branch protection, required reviews), not a Sentinel one.

## 6. Infrastructure security design

- **EC2 types:** only `t2.micro` / `t3.micro` (advisory warning). This keeps cost low, and a smaller instance also limits what an attacker can do with it.
- **EBS encryption:** must be explicitly `true`. I didn't rely on the AWS account-level "encrypt by default" setting, because Sentinel can't see account settings.
- **IMDSv2:** `http_tokens = "required"` stops SSRF attacks reading the instance role credentials from the metadata service. The hop limit is set to 1. Enforced in `compliance_all` (hard-mandatory), and shown per area in `encryption` (advisory).
- **Network:** the server sits in a private subnet with no public IP. SSH is only allowed from the admin network (`10.10.0.0/16`), and HTTPS only inside the VPC. The policy also blocks any port open to the internet except 80/443.

## 7. How policy enforcement prevents non-compliant deployments

```
terraform plan (CLI or VCS)  ->  HCP Terraform runs the plan
                             ->  Sentinel policy check (compliance_all hard + 4 advisory)
                                    all pass            -> apply allowed
                                    hard-mandatory fail -> run stopped, apply not possible
                                    advisory fail       -> warning only, run continues
```

Sentinel runs on the **plan**, before AWS is touched. So a bad change is blocked before it costs money or exposes data. AWS credentials are only stored in the HCP workspace, not on developer laptops, so in normal working the only way to change the infrastructure is through a run that goes through the policy check.

## 8. Testing

Two layers of testing:
1. **Sentinel CLI + mocks:** each of the 6 policy files has a `pass.hcl` test using the compliant mock and a `fail.hcl` test using the non-compliant mock (12 tests). Command: `cd sentinel` then `sentinel test -verbose`. GitHub Actions runs the same tests on every push.
2. **Real plans in HCP Terraform:**
   - Compliant run: default variables → all 5 HCP policies pass. The output is saved in `terraform/tfplan`.
   - Apply + destroy: the compliant plan was applied (17 resources created in eu-west-1, checked in the AWS console) and then destroyed.
   - Non-compliant run: `tests/noncompliant.auto.tfvars` copied into `terraform/` → `compliance_all` fails (hard), so the run is blocked; the advisory policies show which areas failed. The output is saved in `documentation/evidence/tfplan-noncompliant.txt`.

Full list of scenarios: `tests/test-scenarios.md`. Results and screenshots: `documentation/evidence/test-results.md`.

### Evidence screenshots

| # | Screenshot | What it shows |
|---|---|---|
| 00 | [HCP policy set](documentation/evidence/screenshots/00-hcp-policy-set.png) | Policy set `atul00205200-policies`: `compliance_all` (hard-mandatory) + 4 advisory policies, scoped to workspace `sovereignty-ie` |
| 01 | [Sentinel tests (local)](documentation/evidence/screenshots/01-sentinel-test-local.png) | `sentinel test -verbose`: all 12 tests PASS |
| 02 | [GitHub Actions](documentation/evidence/screenshots/02-github-actions-green.png) | Workflow green: Terraform checks + Sentinel tests *(added after first push)* |
| 03 | [Compliant run overview](documentation/evidence/screenshots/03-hcp-compliant-run-overview.png) | Policy checks 5 of 5 passed, +17 resources, "Planned and finished" |
| 04 | [Compliant policy details](documentation/evidence/screenshots/04-hcp-compliant-policy-details.png) | All 5 policies passed |
| 05 | [Non-compliant run blocked](documentation/evidence/screenshots/05-hcp-noncompliant-run-blocked.png) | "Policy check hard failed": run blocked, no Apply |
| 06 | [Non-compliant policy details](documentation/evidence/screenshots/06-hcp-noncompliant-policy-details.png) | `compliance_all` FAIL messages: us-east-1, offshore backup, no encryption, IMDSv1, SSH open |
| 07 | [Apply success](documentation/evidence/screenshots/07-hcp-apply-success.png) | `terraform apply`: policies passed, 17 resources created |
| 08 | [AWS console – Ireland](documentation/evidence/screenshots/08-aws-console-eu-west-1.png) | EC2 resources running in Europe (Ireland) eu-west-1 |
| 09 | [Destroy complete](documentation/evidence/screenshots/09-destroy-complete.png) | `terraform destroy`: all 17 resources removed |

Plan outputs: [`terraform/tfplan`](terraform/tfplan) (compliant) and [`tfplan-noncompliant.txt`](documentation/evidence/tfplan-noncompliant.txt) (blocked).

## 9. Evaluation and decision justification

**How effective Policy as Code is for digital sovereignty.**
It works well for the rules it can see. The checks are automatic, run every time, are the same for everyone and are version-controlled in Git. That is much better than a wiki page or a manual review. I found the fail messages useful because they tell the developer exactly what is wrong. But it only protects infrastructure that goes through Terraform and HCP Terraform. Something created in the AWS console never meets my policies. So I see PaC as one strong layer, not the whole solution. It has to be combined with AWS Organizations SCPs (deny regions outside the EU at account level), AWS Config for drift, and IAM.

**Limitations of region-based data residency controls.**
- The region tells you where the data is **stored**, not **who can access it** or which country's law applies to the provider.
- Some AWS services are global (IAM, CloudFront, Route 53), so their data isn't in one region.
- Logs, metrics, support cases and AWS's own backups can be handled outside the region.
- Tags are only as good as the person setting them. Someone can tag sensitive data as `internal`.
- Data can leave through the application (an API call, an export to a laptop), and Terraform can't see that.

**Importance of supply chain integrity.**
Terraform providers run with full access to our AWS credentials. A malicious provider or module could create hidden resources or send the keys somewhere else. Then all my other policies wouldn't matter, because the attacker would just go around them. Pinning versions, approving sources and checking checksums means we know exactly what code is running. It's the same idea as locking dependency versions in a Java build.

**Limitations of Sentinel and plan-time enforcement.**
- Values that are only known after apply (IDs, some computed attributes) show up as unknown in the plan, so the policy can't check them. I made my policies treat a missing value as a fail where I could.
- Sentinel doesn't see drift or manual changes after apply.
- Policies only run inside HCP Terraform. Someone running Terraform locally with their own keys and a local state skips them completely.
- Soft-mandatory policies can be overridden, so the people with override rights have to be trusted. On my Free plan only one policy could be hard-mandatory, so I combined all blocking rules into `compliance_all`.
- On the Free tier there is a 5-policy limit, only 1 hard-mandatory policy was allowed in my organisation, and there are no VCS-connected policy sets. I had to combine all blocking rules into one policy, duplicate checks in the advisory per-area policies, and keep GitHub and HCP in sync by hand. That could get out of step.

**Challenges of maintaining policies as cloud environments evolve.**
- AWS keeps adding new regions, instance families and services. A new service that stores data won't be in my `data_store_types` list until someone adds it.
- Providers change. Provider v6 added per-resource `region`. Before that, a provider-level region check would have been enough, and after it, that check has a hole in it. Every provider upgrade needs the policies re-tested.
- Approved versions need updating for security patches, otherwise the pin stops us getting fixes.
- Policies need owners, tests and reviews like any other code. That's why I wrote mocks and run `sentinel test` in CI.

## 10. AI tool declaration

**Tool:** Claude (Anthropic), Claude Opus 5.5, used on claude.ai, November 2026.

I used Claude like a tutor to understand the topics, and to get a starting draft that I then ran, tested and changed myself.

**Prompts I used:**

*Understanding the assignment*
1. "can you explain what this assignment is about in simple words" (uploaded the brief)
2. "what is hashicorp sentinel and how does it check the terraform plan"
3. "is it ok to use my own aws account for this assignment"

*Learning the concepts*
4. "what does digital sovereignty mean, why does it matter if data is in ireland"
5. "whats the difference between data residency and data sovereignty"
6. "what is the provider and the exact provider version that was installed"
7. "so hashicorp doesn't only create sentinel, is it also used to create resources in terraform"
8. "is terraform created by hashicorp"
9. "what does HCP terraform do"
10. "what is a supply chain attack in terraform, can you give a simple example"
11. "what is the .terraform.lock.hcl file for, do i need to push it to github"
12. "what is imdsv2, why do ec2 instances need it"
13. "difference between advisory, soft mandatory and hard mandatory in sentinel?"
14. "what are sentinel mocks, how can i test policies without creating anything in aws"
15. "what things can sentinel not check at plan time"

*Building it*
16. "can you help me write simple terraform code for aws in eu-west-1 with a vpc, a t3.micro ec2, an ebs volume and an s3 bucket, free tier only" – I used the answer to understand each .tf file
17. "how do i set up terraform and the sentinel cli on my windows laptop"
18. "how do i create an iam user in aws for hcp terraform, what permissions does it need"
19. "how do i set up hcp terraform free, make an org and a workspace and connect it to my laptop"
20. "only sovereignty is hard mandatory, all others are advisory, is it an issue? ... yes please" – this is where the combined compliance_all policy came from
21. "how do i run a compliant plan and a non-compliant plan and save the output to a tfplan file"

**My own work:**
- Installed Terraform (1.17.1) and the Sentinel CLI on my Windows laptop. `terraform` was not found at first, so I fixed it by adding the folder to PATH.
- Created the IAM user `hcp-terraform-l00205200` in my own AWS account with only the permissions it needs (EC2, VPC, S3, SSM read-only), and a budget alert.
- Set up HCP Terraform Free: organisation `ATUL00205200`, workspace `sovereignty-ie`, policy set `atul00205200-policies`, connected to my laptop with `terraform login` and `terraform init`.
- Ran `sentinel test` locally (12 tests passed), the compliant plan (17 resources in eu-west-1, all policies passed) and the non-compliant plan (18 resources in us-east-1, blocked with "Organization Policy Check hard failed"), and saved all outputs, logs and screenshots as evidence.
- Ran `terraform apply` on the compliant plan. The policy check passed again and the resources were created in AWS eu-west-1 (Ireland). I checked them in the AWS console, then ran `terraform destroy` to remove everything and avoid costs.
- Checked and edited the code, policies and documents.

**Problems I hit and fixed myself:**
1. **AWS credentials:** the first plan failed with "No valid credential sources found". I had typed the access key into the *Key* field of the workspace variable. I deleted it and added `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as sensitive environment variables.
2. **Free plan enforcement limits:** HCP did not let me choose soft-mandatory, and after the first policy it said I had exceeded the number of hard-mandatory policies, so only advisory was left. I changed my design: all blocking rules went into one hard-mandatory policy (`compliance_all`), instance type became an advisory cost rule, and IMDSv2 moved into the encryption checks.
3. **Wrong code pasted:** I pasted the encryption code into the `network` policy by mistake. I spotted it in the plan output, because the network policy was showing encryption rules, and fixed it.
4. **Out-of-date comments:** after the redesign, some policy comments still described the old enforcement levels. I updated them so the descriptions in HCP match what the policies really do.


## 11. References

- HashiCorp (2026) *Sentinel documentation*. Available at: https://developer.hashicorp.com/sentinel/docs (Accessed: 13 November 2026).
- HashiCorp (2026) *HCP Terraform policy enforcement overview*. Available at: https://developer.hashicorp.com/terraform/cloud-docs/policy-enforcement (Accessed: 13 November 2026).
- HashiCorp (2026) *Dependency lock file*. Available at: https://developer.hashicorp.com/terraform/language/files/dependency-lock (Accessed: 13 November 2026).
- Amazon Web Services (2026) *Opening the AWS European Sovereign Cloud*. Available at: https://aws.amazon.com/blogs/aws/opening-the-aws-european-sovereign-cloud/ (Accessed: 13 November 2026).
- Government of Ireland (2025) *Ireland signs Declaration for European Digital Sovereignty*. (Link from assignment brief.)
- Houses of the Oireachtas (2026) *Telecommunications Infrastructure, Dáil Éireann Debate, 13 May 2026, Question 75*. (Link from assignment brief.)
