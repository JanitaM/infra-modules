# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  role_name          = "test-role"
  assume_role_policy = "{}"
}

run "no_additional_policies_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0
    error_message = "no policy attachments should be created when policy_arns is empty"
  }
}

run "policies_attached_when_set" {
  command = plan

  variables {
    policy_arns = [
      "arn:aws:iam::123456789012:policy/read-policy",
      "arn:aws:iam::123456789012:policy/send-policy",
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 2
    error_message = "one policy attachment should be created per entry in policy_arns"
  }
}

run "handles_not_yet_known_policy_arn" {
  command = plan

  module {
    source = "./tests/fixtures/unknown-policy-arn"
  }

  providers = {
    aws = aws
  }

  # The meaningful check is that this run's `plan` succeeds at all: before the
  # index-keyed for_each fix, toset() over a list containing this not-yet-known
  # value made Terraform unable to resolve for_each, and the plan itself failed
  # with "Invalid for_each argument" — the whole run would report "fail" here,
  # regardless of any assert. This assert just confirms the plan reached a
  # normal, evaluable state once that no longer happens.
  assert {
    condition     = module.under_test.role_name == "test-role"
    error_message = "module should plan successfully even when one policy_arns entry is not yet known at plan time (e.g. a brand-new module's policy-ARN output before its first apply) — regression test for the toset()-on-unknown-values 'Invalid for_each argument' failure"
  }
}
