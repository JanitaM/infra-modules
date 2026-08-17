# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  budget_name  = "test-budget"
  limit_amount = "100.0"
  alert_emails = ["ops@example.com"]
}

run "sns_topic_omitted_when_unset" {
  command = plan

  assert {
    condition     = tolist(aws_budgets_budget.primary.notification)[0].subscriber_sns_topic_arns == null
    error_message = "subscriber_sns_topic_arns should be null when sns_topic_arn is not set"
  }
}

run "sns_topic_included_when_set" {
  command = plan

  variables {
    sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:budget-alerts"
  }

  assert {
    condition     = tolist(tolist(aws_budgets_budget.primary.notification)[0].subscriber_sns_topic_arns) == tolist(["arn:aws:sns:us-east-1:123456789012:budget-alerts"])
    error_message = "subscriber_sns_topic_arns should contain sns_topic_arn when it is set"
  }
}

run "rejects_invalid_time_unit" {
  command = plan

  variables {
    time_unit = "WEEKLY"
  }

  expect_failures = [var.time_unit]
}

run "rejects_empty_alert_emails" {
  command = plan

  variables {
    alert_emails = []
  }

  expect_failures = [var.alert_emails]
}

run "rejects_invalid_comparison_operator" {
  command = plan

  variables {
    comparison_operator = "NOT_EQUAL_TO"
  }

  expect_failures = [var.comparison_operator]
}

run "rejects_invalid_notification_type" {
  command = plan

  variables {
    notification_type = "PREDICTED"
  }

  expect_failures = [var.notification_type]
}
