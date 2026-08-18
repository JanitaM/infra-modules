package main

import rego.v1

# acm module policy.
#
# Organized by security baseline intent, matching global.rego's convention.
# This intent — validation must be DNS, not EMAIL — is specific to ACM
# certificates, so it lives here rather than in global.rego. EMAIL validation
# depends on a human clicking an approval link sent to a WHOIS/domain
# contact address, and isn't auditable or automatable the way DNS validation
# is; the acm module defaults to DNS but still lets validation_method be set
# to EMAIL, so this catches that opt-in at plan time.

# ---- Intent: certificates must validate via DNS, not EMAIL ----

deny contains msg if {
  cert := input.resource_changes[_]
  cert.type == "aws_acm_certificate"
  object.get(cert.change.after, "validation_method", "") == "EMAIL"

  msg := sprintf(
    "ACM certificate '%s' uses EMAIL validation. Use validation_method = \"DNS\" instead — EMAIL depends on manual approval and isn't auditable (see modules/aws/acm).",
    [cert.address],
  )
}
