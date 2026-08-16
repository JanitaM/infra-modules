package main

import rego.v1

# cloudwatch module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# alerting/notification topics must be encrypted at rest — is specific to
# SNS, so it lives here rather than in global.rego. This also catches a topic
# someone writes by hand instead of through modules/aws/cloudwatch, which
# always sets kms_master_key_id.

sns_unencrypted(topic) if not topic.change.after.kms_master_key_id

sns_unencrypted(topic) if topic.change.after.kms_master_key_id == null

# ---- Intent: alerting/notification topics must be encrypted at rest ----

deny contains msg if {
  topic := input.resource_changes[_]
  topic.type == "aws_sns_topic"
  sns_unencrypted(topic)

  msg := sprintf(
    "SNS topic '%s' has no kms_master_key_id set. Alerting/notification topics must be encrypted at rest — see modules/aws/cloudwatch.",
    [topic.address],
  )
}
