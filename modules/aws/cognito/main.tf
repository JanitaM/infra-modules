resource "aws_cognito_user_pool" "primary" {
  name = var.user_pool_name

  # IA-2: managed identity requires MFA — no opt-out. See
  # policy/aws/modules/cognito.rego for the plan-time check.
  mfa_configuration = "ON"
  software_token_mfa_configuration {
    enabled = true
  }

  # IA-5: strong password baseline, hardcoded alongside the MFA requirement
  # above — both express the same "managed identity requires MFA" intent.
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  auto_verified_attributes = var.auto_verified_attributes

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "primary" {
  name         = var.client_name
  user_pool_id = aws_cognito_user_pool.primary.id

  generate_secret = false

  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  prevent_user_existence_errors = "ENABLED"
}
