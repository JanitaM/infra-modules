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

run "handles_not_yet_known_additional_policy_arn" {
  command = plan

  module {
    source = "./tests/fixtures/unknown-policy-arn"
  }

  providers = {
    aws = aws
  }

  override_data {
    target = module.under_test.data.aws_iam_policy_document.assume_role
    values = {
      json = "{}"
    }
  }

  # The meaningful check is that this run's `plan` succeeds at all: before the
  # index-keyed for_each fix, toset() over a list containing this not-yet-known
  # value made Terraform unable to resolve for_each, and the plan itself failed
  # with "Invalid for_each argument" — the whole run would report "fail" here,
  # regardless of any assert. This assert just confirms the plan reached a
  # normal, evaluable state once that no longer happens.
  assert {
    condition     = module.under_test.function_name == "test-function"
    error_message = "module should plan successfully even when one additional_policy_arns entry is not yet known at plan time (e.g. a brand-new module's policy-ARN output before its first apply) — regression test for the toset()-on-unknown-values 'Invalid for_each argument' failure"
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

run "no_layers_by_default" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.primary.layers) == 0
    error_message = "no layers should be attached when var.layers is empty"
  }
}

run "layers_attached_when_set" {
  command = plan

  variables {
    layers = [
      "arn:aws:lambda:us-east-1:753240598075:layer:LambdaAdapterLayerX86:24",
    ]
  }

  assert {
    condition     = length(aws_lambda_function.primary.layers) == 1
    error_message = "one layer should be attached per entry in var.layers"
  }
}

run "rejects_more_than_five_layers" {
  command = plan

  variables {
    layers = [
      "arn:aws:lambda:us-east-1:111111111111:layer:one:1",
      "arn:aws:lambda:us-east-1:111111111111:layer:two:1",
      "arn:aws:lambda:us-east-1:111111111111:layer:three:1",
      "arn:aws:lambda:us-east-1:111111111111:layer:four:1",
      "arn:aws:lambda:us-east-1:111111111111:layer:five:1",
      "arn:aws:lambda:us-east-1:111111111111:layer:six:1",
    ]
  }

  expect_failures = [var.layers]
}

run "defaults_to_buffered_invoke_mode" {
  command = plan

  assert {
    condition     = aws_lambda_function_url.primary.invoke_mode == "BUFFERED"
    error_message = "invoke_mode should default to BUFFERED"
  }
}

run "sets_response_stream_invoke_mode_when_requested" {
  command = plan

  variables {
    invoke_mode = "RESPONSE_STREAM"
  }

  assert {
    condition     = aws_lambda_function_url.primary.invoke_mode == "RESPONSE_STREAM"
    error_message = "invoke_mode should be RESPONSE_STREAM when requested"
  }
}

run "rejects_invalid_invoke_mode" {
  command = plan

  variables {
    invoke_mode = "STREAMING"
  }

  expect_failures = [var.invoke_mode]
}

run "no_publish_by_default" {
  command = plan

  assert {
    condition     = aws_lambda_function.primary.publish == false
    error_message = "publish should default to false"
  }

  assert {
    condition     = length(aws_lambda_alias.primary) == 0
    error_message = "no alias should be created when publish is false"
  }
}

run "alias_created_when_publish_requested" {
  command = plan

  variables {
    publish = true
  }

  assert {
    condition     = aws_lambda_function.primary.publish == true
    error_message = "publish should be true when requested"
  }

  assert {
    condition     = length(aws_lambda_alias.primary) == 1
    error_message = "an alias should be created when publish is true"
  }

  assert {
    condition     = aws_lambda_alias.primary[0].name == "live"
    error_message = "alias_name should default to \"live\""
  }
}

run "alias_name_is_configurable" {
  command = plan

  variables {
    publish    = true
    alias_name = "stable"
  }

  assert {
    condition     = aws_lambda_alias.primary[0].name == "stable"
    error_message = "alias should use the requested alias_name"
  }
}

run "function_url_targets_latest_by_default" {
  command = plan

  assert {
    condition     = aws_lambda_function_url.primary.qualifier == null
    error_message = "qualifier should be null ($LATEST) by default"
  }
}

run "function_url_targets_qualifier_when_set" {
  command = plan

  variables {
    publish   = true
    qualifier = "live"
  }

  assert {
    condition     = aws_lambda_function_url.primary.qualifier == "live"
    error_message = "qualifier should be passed through to the Function URL when set"
  }
}

run "rejects_qualifier_without_publish" {
  command = plan

  variables {
    publish   = false
    qualifier = "live"
  }

  expect_failures = [aws_lambda_function_url.primary]
}
