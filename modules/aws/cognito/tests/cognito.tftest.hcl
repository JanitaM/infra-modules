# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
#
# cognito's main.tf is otherwise static config (MFA, password policy, and
# recovery mechanisms are all hardcoded, no opt-out) — the only thing worth
# testing is the one validation rule, plus the Hosted UI/OAuth opt-in added
# for consumers doing an authorization-code flow (not just SRP).
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

run "defaults_to_no_hosted_ui_and_srp_only_client" {
  command = plan

  assert {
    condition     = length(aws_cognito_user_pool_domain.primary) == 0
    error_message = "no hosted_ui_domain_prefix should create no domain resource"
  }

  assert {
    condition     = aws_cognito_user_pool_client.primary.allowed_oauth_flows_user_pool_client == false
    error_message = "OAuth should stay off when callback_urls is empty, matching this module's original SRP-only behavior"
  }
}

run "enables_oauth_client_when_domain_and_callback_urls_set" {
  command = plan

  variables {
    hosted_ui_domain_prefix = "test-pool-auth"
    callback_urls           = ["https://example.com/callback"]
    logout_urls             = ["https://example.com/"]
  }

  assert {
    condition     = length(aws_cognito_user_pool_domain.primary) == 1
    error_message = "hosted_ui_domain_prefix should create exactly one domain resource"
  }

  assert {
    condition     = aws_cognito_user_pool_client.primary.allowed_oauth_flows_user_pool_client == true
    error_message = "callback_urls should turn on the client's authorization-code flow"
  }

  assert {
    condition     = tolist(aws_cognito_user_pool_client.primary.allowed_oauth_flows) == tolist(["code"])
    error_message = "allowed_oauth_flows should be [\"code\"] once enabled"
  }

  assert {
    condition     = toset(aws_cognito_user_pool_client.primary.allowed_oauth_scopes) == toset(["openid", "email", "profile"])
    error_message = "allowed_oauth_scopes should default to [\"openid\", \"email\", \"profile\"]"
  }
}

run "rejects_callback_urls_without_hosted_ui_domain" {
  command = plan

  variables {
    callback_urls = ["https://example.com/callback"]
  }

  expect_failures = [check.hosted_ui_domain_required_for_oauth]
}

run "defaults_to_no_refresh_token_rotation" {
  command = plan

  assert {
    condition     = length(aws_cognito_user_pool_client.primary.refresh_token_rotation) == 0
    error_message = "no refresh_token_rotation input should produce no refresh_token_rotation block"
  }
}

run "enables_refresh_token_rotation_when_set" {
  command = plan

  variables {
    refresh_token_rotation = {
      feature                    = "ENABLED"
      retry_grace_period_seconds = 0
    }
  }

  assert {
    condition     = length(aws_cognito_user_pool_client.primary.refresh_token_rotation) == 1
    error_message = "a supplied refresh_token_rotation should produce exactly one refresh_token_rotation block"
  }

  assert {
    condition     = aws_cognito_user_pool_client.primary.refresh_token_rotation[0].feature == "ENABLED"
    error_message = "refresh_token_rotation.feature should pass through to the block"
  }

  assert {
    condition     = aws_cognito_user_pool_client.primary.refresh_token_rotation[0].retry_grace_period_seconds == 0
    error_message = "retry_grace_period_seconds should pass through to the block"
  }
}

run "rejects_invalid_refresh_token_rotation_feature" {
  command = plan

  variables {
    refresh_token_rotation = {
      feature = "MAYBE"
    }
  }

  expect_failures = [var.refresh_token_rotation]
}
