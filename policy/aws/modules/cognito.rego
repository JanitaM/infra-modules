package main

import rego.v1

# cognito module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# managed identity requires MFA — is specific to Cognito user pools, so it
# lives here rather than in global.rego alongside the cross-resource intents
# (encryption, public storage) that recur across multiple resource types.

# ---- Intent: managed identity requires MFA ----

deny contains msg if {
  pool := input.resource_changes[_]
  pool.type == "aws_cognito_user_pool"
  pool.change.after.mfa_configuration != "ON"

  msg := sprintf(
    "Cognito user pool '%s' does not require MFA (mfa_configuration = '%v'). Managed identity requires MFA — see modules/aws/cognito.",
    [pool.address, pool.change.after.mfa_configuration],
  )
}
