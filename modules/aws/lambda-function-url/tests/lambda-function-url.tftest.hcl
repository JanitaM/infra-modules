# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
#
# aws_iam_policy_document is normally computed locally by the provider, not
# fetched from a real API — mock_provider mocks it too, so it needs an
# explicit override or its json output comes back invalid.
mock_provider "aws" {
  override_data {
    target = data.aws_iam_policy_document.assume_role
    values = {
      json = "{}"
    }
  }
}

variables {
  function_name = "test-function"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "function.zip"
}

run "no_additional_policies_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.additional) == 0
    error_message = "no additional policy attachments should be created when additional_policy_arns is empty"
  }
}

run "additional_policies_attached_when_set" {
  command = plan

  variables {
    additional_policy_arns = [
      "arn:aws:iam::123456789012:policy/read-policy",
      "arn:aws:iam::123456789012:policy/send-policy",
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.additional) == 2
    error_message = "one policy attachment should be created per entry in additional_policy_arns"
  }
}

run "no_environment_block_by_default" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.primary.environment) == 0
    error_message = "no environment block should be created when environment_variables is empty"
  }
}

run "environment_block_created_when_set" {
  command = plan

  variables {
    environment_variables = {
      FOO = "bar"
    }
  }

  assert {
    condition     = length(aws_lambda_function.primary.environment) == 1
    error_message = "an environment block should be created when environment_variables is non-empty"
  }
}

run "rejects_invalid_runtime" {
  command = plan

  variables {
    runtime = "ruby3.2"
  }

  expect_failures = [var.runtime]
}
