# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
#
# aws_iam_policy_document is normally computed locally by the provider, not
# fetched from a real API — mock_provider mocks it too, so it needs an
# explicit override or its json output comes back invalid.
mock_provider "aws" {
  override_data {
    target = data.aws_iam_policy_document.read
    values = {
      json = "{}"
    }
  }
}

variables {
  secret_name = "test-secret"
}

run "no_version_or_policy_by_default" {
  command = plan

  assert {
    condition     = length(aws_secretsmanager_secret_version.primary) == 0
    error_message = "no secret version should be created when secret_string is not set"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_policy.primary) == 0
    error_message = "no resource policy should be created when resource_policy_json is not set"
  }
}

run "version_created_when_secret_string_set" {
  command = plan

  variables {
    secret_string = "super-secret-value"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_version.primary) == 1
    error_message = "a secret version should be created when secret_string is set"
  }
}

run "resource_policy_created_when_set" {
  command = plan

  variables {
    resource_policy_json = "{}"
  }

  assert {
    condition     = length(aws_secretsmanager_secret_policy.primary) == 1
    error_message = "a resource policy should be created when resource_policy_json is set"
  }
}

run "accepts_zero_recovery_window" {
  command = plan

  variables {
    recovery_window_in_days = 0
  }

  assert {
    condition     = aws_secretsmanager_secret.primary.recovery_window_in_days == 0
    error_message = "recovery_window_in_days of 0 should be accepted"
  }
}

run "rejects_recovery_window_below_seven" {
  command = plan

  variables {
    recovery_window_in_days = 5
  }

  expect_failures = [var.recovery_window_in_days]
}

run "rejects_recovery_window_above_thirty" {
  command = plan

  variables {
    recovery_window_in_days = 31
  }

  expect_failures = [var.recovery_window_in_days]
}
