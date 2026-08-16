package main

import rego.v1

# budget module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# budgets must never be silently unmonitored — is specific to AWS Budgets, so
# it lives here rather than in global.rego. This also catches a budget
# someone writes by hand instead of through modules/aws/budget, which always
# requires at least one notification subscriber.

# ---- Intent: budgets must always have at least one notification ----

has_subscriber(n) if count(object.get(n, "subscriber_email_addresses", [])) > 0

has_subscriber(n) if count(object.get(n, "subscriber_sns_topic_arns", [])) > 0

deny contains msg if {
  b := input.resource_changes[_]
  b.type == "aws_budgets_budget"

  notifications := object.get(b.change.after, "notification", [])
  matching := [n | n := notifications[_]; has_subscriber(n)]
  count(matching) == 0

  msg := sprintf(
    "AWS Budget '%s' has no notification with a subscriber. A budget nobody is notified about is silently useless — see modules/aws/budget.",
    [b.address],
  )
}
