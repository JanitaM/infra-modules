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

# ---- log-based metric filter ----

run "no_metric_filter_by_default" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_metric_filter.primary) == 0
    error_message = "no aws_cloudwatch_log_metric_filter should be created when log_group_name is not set"
  }
}

run "metric_filter_created_when_log_group_set" {
  command = plan

  variables {
    log_group_name     = "/aws/lambda/example"
    log_filter_pattern = "\"Failed to send email\""
  }

  assert {
    condition     = length(aws_cloudwatch_log_metric_filter.primary) == 1
    error_message = "an aws_cloudwatch_log_metric_filter should be created when log_group_name and log_filter_pattern are set"
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.primary[0].log_group_name == "/aws/lambda/example"
    error_message = "the filter should target the given log group"
  }

  # The alarm has to watch exactly what the filter publishes — if these ever
  # diverge the alarm silently never fires.
  assert {
    condition = alltrue([
      aws_cloudwatch_log_metric_filter.primary[0].metric_transformation[0].name == aws_cloudwatch_metric_alarm.primary.metric_name,
      aws_cloudwatch_log_metric_filter.primary[0].metric_transformation[0].namespace == aws_cloudwatch_metric_alarm.primary.namespace,
    ])
    error_message = "the filter's metric transformation should publish the same namespace/metric_name the alarm watches"
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.primary[0].metric_transformation[0].default_value == "0"
    error_message = "the metric transformation should default to 0 so the alarm does not sit in INSUFFICIENT_DATA"
  }
}

run "rejects_log_group_without_pattern" {
  command = plan

  variables {
    log_group_name = "/aws/lambda/example"
  }

  expect_failures = [aws_cloudwatch_metric_alarm.primary]
}

run "rejects_pattern_without_log_group" {
  command = plan

  variables {
    log_filter_pattern = "\"Failed to send email\""
  }

  expect_failures = [aws_cloudwatch_metric_alarm.primary]
}

# ---- existing topic reuse ----

run "creates_own_topic_by_default" {
  command = plan

  assert {
    condition     = length(aws_sns_topic.alerts) == 1
    error_message = "a dedicated aws_sns_topic should be created when existing_topic_arn is not set"
  }
}

run "reuses_existing_topic_when_set" {
  command = plan

  variables {
    existing_topic_arn = "arn:aws:sns:us-east-1:123456789012:shared-alerts"
    alert_email        = "ops@example.com"
  }

  assert {
    condition     = length(aws_sns_topic.alerts) == 0
    error_message = "no aws_sns_topic should be created when existing_topic_arn is set"
  }

  assert {
    condition = alltrue([
      aws_cloudwatch_metric_alarm.primary.alarm_actions == toset(["arn:aws:sns:us-east-1:123456789012:shared-alerts"]),
      aws_cloudwatch_metric_alarm.primary.ok_actions == toset(["arn:aws:sns:us-east-1:123456789012:shared-alerts"]),
    ])
    error_message = "the alarm should notify the passed-in topic"
  }

  assert {
    condition     = aws_sns_topic_subscription.email[0].topic_arn == "arn:aws:sns:us-east-1:123456789012:shared-alerts"
    error_message = "an alert_email subscription should attach to the passed-in topic"
  }
}
