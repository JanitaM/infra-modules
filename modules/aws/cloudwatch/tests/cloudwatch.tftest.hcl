# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  alarm_name          = "test-alarm"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
}

run "no_subscription_when_alert_email_unset" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 0
    error_message = "no aws_sns_topic_subscription should be created when alert_email is not set"
  }
}

run "subscription_created_when_alert_email_set" {
  command = plan

  variables {
    alert_email = "ops@example.com"
  }

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 1
    error_message = "an aws_sns_topic_subscription should be created when alert_email is set"
  }

  assert {
    condition     = aws_sns_topic_subscription.email[0].endpoint == "ops@example.com"
    error_message = "the subscription endpoint should be alert_email"
  }
}

run "rejects_invalid_statistic" {
  command = plan

  variables {
    statistic = "Median"
  }

  expect_failures = [var.statistic]
}

run "rejects_invalid_comparison_operator" {
  command = plan

  variables {
    comparison_operator = "EqualToThreshold"
  }

  expect_failures = [var.comparison_operator]
}

run "rejects_invalid_treat_missing_data" {
  command = plan

  variables {
    treat_missing_data = "unknown"
  }

  expect_failures = [var.treat_missing_data]
}
