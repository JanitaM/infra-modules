terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# AU-6: a budget with no notification silently tracks spend that nobody
# sees. alert_emails has no default and must be non-empty (see variables.tf),
# so a notification always exists — hardcoded, no opt-out. See
# policy/aws/modules/budget.rego for the plan-time check that also catches a
# budget someone writes by hand instead of through this module.
resource "aws_budgets_budget" "primary" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = var.limit_amount
  limit_unit   = var.limit_unit
  time_unit    = var.time_unit

  notification {
    comparison_operator        = var.comparison_operator
    threshold                  = var.threshold_percentage
    threshold_type             = "PERCENTAGE"
    notification_type          = var.notification_type
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = var.sns_topic_arn != null ? [var.sns_topic_arn] : null
  }

  tags = var.tags
}
