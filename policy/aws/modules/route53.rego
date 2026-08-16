package main

import rego.v1

# route53 module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# DNS zones must be tamper-evident — is specific to Route 53 hosted zones, so
# it lives here rather than in global.rego alongside the cross-resource
# intents (encryption, public storage) that recur across multiple resource
# types.

# ---- Intent: DNS zones must be tamper-evident ----

deny contains msg if {
  zone := input.resource_changes[_]
  zone.type == "aws_route53_zone"

  matching_dnssec := [d |
    d := input.resource_changes[_]
    d.type == "aws_route53_hosted_zone_dnssec"
    module_path(d.address) == module_path(zone.address)
  ]
  count(matching_dnssec) == 0

  msg := sprintf(
    "Route 53 zone '%s' has no DNSSEC signing enabled. Public hosted zones must be tamper-evident — see modules/aws/route53.",
    [zone.address],
  )
}
