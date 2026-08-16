package main

import rego.v1

# ssm module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# configuration values in Parameter Store must be encrypted — is specific to
# SSM parameters, so it lives here rather than in global.rego. This also
# catches a parameter someone writes by hand instead of through
# modules/aws/ssm, which always sets SecureString.

# ---- Intent: configuration values in Parameter Store must be encrypted ----

deny contains msg if {
  p := input.resource_changes[_]
  p.type == "aws_ssm_parameter"
  p.change.after.type != "SecureString"

  msg := sprintf(
    "SSM parameter '%s' has type '%s'. Parameters must use type SecureString — a plaintext String or StringList value is readable by anyone with ssm:GetParameter alone, no KMS decrypt permission required — see modules/aws/ssm.",
    [p.address, p.change.after.type],
  )
}
