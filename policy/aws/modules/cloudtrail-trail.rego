package main

import rego.v1

# cloudtrail-trail module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. The module
# hardcodes log file validation on with no opt-out, but this check catches a
# trail written by hand instead of through modules/aws/cloudtrail-trail, or
# one where that guarantee somehow regressed.

# ---- Intent: account activity must be auditable ----

deny contains msg if {
  t := input.resource_changes[_]
  t.type == "aws_cloudtrail"

  t.change.after.enable_log_file_validation != true

  msg := sprintf(
    "CloudTrail trail '%s' does not have log file validation enabled. Without it, tampering with delivered log files is undetectable — see modules/aws/cloudtrail-trail.",
    [t.address],
  )
}
