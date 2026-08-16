package main

import rego.v1

# secrets-manager module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# secrets must not grant public/wildcard access — is specific to Secrets
# Manager resource policies, so it lives here rather than in global.rego.
#
# Reuses as_array/1 from global.rego (same "main" package, loaded together).

principal_is_wildcard(p) if p == "*"

principal_is_wildcard(p) if {
  some v in as_array(p.AWS)
  v == "*"
}

# ---- Intent: secrets must not grant public/wildcard access ----

deny contains msg if {
  pol := input.resource_changes[_]
  pol.type == "aws_secretsmanager_secret_policy"
  doc := json.unmarshal(pol.change.after.policy)
  some stmt in as_array(doc.Statement)
  stmt.Effect == "Allow"
  principal_is_wildcard(stmt.Principal)

  msg := sprintf(
    "Secrets Manager resource policy '%s' grants a wildcard (*) principal. Secrets must never be publicly or cross-account accessible without an explicit, reviewed principal — see modules/aws/secrets-manager.",
    [pol.address],
  )
}
