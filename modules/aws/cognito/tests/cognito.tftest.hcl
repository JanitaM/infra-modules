# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
#
# cognito's main.tf is otherwise static config (MFA, password policy, and
# recovery mechanisms are all hardcoded, no opt-out) — the only thing worth
# testing is the one validation rule.
mock_provider "aws" {}

variables {
  user_pool_name = "test-pool"
}

run "accepts_default_auto_verified_attributes" {
  command = plan

  assert {
    condition     = tolist(aws_cognito_user_pool.primary.auto_verified_attributes) == tolist(["email"])
    error_message = "auto_verified_attributes should default to [\"email\"]"
  }
}

run "rejects_invalid_auto_verified_attribute" {
  command = plan

  variables {
    auto_verified_attributes = ["username"]
  }

  expect_failures = [var.auto_verified_attributes]
}
