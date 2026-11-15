# Technical Report – Limitations and Recommendations

**Raju Augustine (L00205200) – Policy as Code for Digital Sovereignty, organisation ATUL00205200**

**Summary.** I built a Terraform project for AWS and Sentinel policies that run in HCP Terraform Free before every apply. Because Free only allowed one hard-mandatory policy, all blocking rules (sovereignty, supply chain, encryption, IMDSv2, network) are combined in `compliance_all`, with four advisory per-area policies alongside it. The compliant plan passed all policies. The non-compliant plan (us-east-1, an offshore backup bucket, `t3.large`, IMDSv1, no encryption, SSH open to the world) was blocked before anything was created. The policies were also tested with pass/fail mocks using `sentinel test`, both locally and in GitHub Actions.

## Final limitations

1. **Only Terraform runs are protected.** Changes made in the AWS console, with the CLI, or with Terraform run locally against local state never reach Sentinel.
2. **Plan-time only.** Values known only after apply can't be checked, and Sentinel doesn't see drift or changes made after deployment.
3. **Region ≠ sovereignty.** `eu-west-1` keeps data physically in Ireland, but AWS is a US-owned provider. Global services (IAM, CloudFront), logs, support access and admin access aren't controlled by a region check.
4. **Tags rely on people.** Data residency depends on the `DataClassification` tag being set correctly. A sensitive resource tagged `internal` gets less protection.
5. **Supply chain gaps.** Sentinel can't read `.terraform.lock.hcl`, public registry modules aren't signed, and nested module code isn't reviewed. CI checks the lock file, but a compromised maintainer or Git tag could still get through.
6. **Free tier limits.** One policy set with at most 5 policies, and no VCS-linked policy sets. only one policy could be hard-mandatory, so all blocking rules sit in one combined policy (duplicated in advisory per-area policies), instance type is advisory only, and I had to paste policies into HCP by hand, so GitHub and HCP can get out of sync.
7. **Maintenance.** New AWS services, regions, instance types and provider versions (e.g. per-resource `region` in provider v6) all need policy updates and re-testing.

## Recommendations

1. **Add guardrails at account level.** Use AWS Organizations SCPs to deny all regions except `eu-west-1`, so console and CLI changes are blocked too.
2. **Add detection after deployment.** Use AWS Config rules (encrypted volumes, restricted SSH, required tags) and CloudTrail to catch drift and manual changes.
3. **Control keys and access.** Use KMS customer-managed keys for sensitive data, least-privilege IAM with MFA, and review where admins are based. For the highest-sensitivity workloads, consider the AWS European Sovereign Cloud (Germany), accepting that it is not in Ireland.
4. **Harden the supply chain.** Host approved modules in a private registry, pin GitHub Actions to commit SHAs, enable branch protection with required reviews, and keep the CI lock-file check.
5. **Upgrade the HCP plan when the organisation grows** (Standard or Premium) to get VCS-linked policy sets and more policies, so each area can be its own hard-mandatory policy (no duplicated code) and cost rules like instance type can be soft-mandatory with an admin override.
6. **Treat policies as code.** Give each policy an owner, keep its mocks updated, run `sentinel test` on every change, and review the approved region, version and instance lists every quarter.
7. **Only allow Terraform runs through HCP.** Remove AWS keys from developer machines, so every change has to go through the policy check.

*AI use: Claude Opus 5.5 (Anthropic) helped with first drafts. Prompts and my own contribution are listed in README.md section 10.*
