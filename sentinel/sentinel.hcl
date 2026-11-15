# sentinel.hcl - policy set for ATUL00205200 (L00205200)
#
# HCP Terraform Free limits in my organisation:
#   1 policy set, max 5 policies, only 1 hard-mandatory, the rest advisory.
# So:
#   compliance_all = ALL blocking rules in one hard-mandatory policy
#   supply_chain / encryption / network = same checks again as advisory,
#                                         so each area shows its own result in HCP
#   ec2_instance   = instance type (cost rule) - advisory on purpose
#
# Policies are pasted into HCP by hand (Free plan has no VCS-connected policy sets).

policy "compliance_all" {
  source            = "./compliance_all.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "supply_chain" {
  source            = "./supply_chain.sentinel"
  enforcement_level = "advisory"
}

policy "encryption" {
  source            = "./encryption.sentinel"
  enforcement_level = "advisory"
}

policy "network" {
  source            = "./network.sentinel"
  enforcement_level = "advisory"
}

policy "ec2_instance" {
  source            = "./ec2_instance.sentinel"
  enforcement_level = "advisory"
}

# Not added to HCP (5-policy limit) - its checks are inside compliance_all.
# Kept here so it can still be tested on its own with sentinel test.
policy "sovereignty" {
  source            = "./sovereignty.sentinel"
  enforcement_level = "advisory"
}
