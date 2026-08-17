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
  parameter_name = "/test/param"
  value          = "super-secret-value"
}

run "looks_up_default_kms_alias_when_unset" {
  command = plan

  assert {
    condition     = length(data.aws_kms_alias.ssm_default) == 1
    error_message = "the default alias/aws/ssm alias should be looked up when kms_key_id is not set"
  }
}

run "skips_default_kms_alias_when_kms_key_id_set" {
  command = plan

  variables {
    kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/1234abcd-1234-abcd-1234-123456789012"
  }

  assert {
    condition     = length(data.aws_kms_alias.ssm_default) == 0
    error_message = "the default alias should not be looked up when kms_key_id is set"
  }
}

run "rejects_invalid_tier" {
  command = plan

  variables {
    tier = "Basic"
  }

  expect_failures = [var.tier]
}
