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

  # OAuth2/Hosted UI is opt-in — a client with no callback_urls stays SRP-only, matching this
  # module's original behavior. See the check block below: enabling this without
  # hosted_ui_domain_prefix is rejected by AWS at apply time (the pool needs a domain before
  # any client on it can be OAuth-enabled).
  allowed_oauth_flows_user_pool_client = length(var.callback_urls) > 0
  allowed_oauth_flows                  = length(var.callback_urls) > 0 ? ["code"] : null
  allowed_oauth_scopes                 = length(var.callback_urls) > 0 ? var.allowed_oauth_scopes : null
  callback_urls                        = length(var.callback_urls) > 0 ? var.callback_urls : null
  logout_urls                          = length(var.callback_urls) > 0 ? var.logout_urls : null
  supported_identity_providers         = length(var.callback_urls) > 0 ? ["COGNITO"] : null
}

# AC-3/IA-2: the Hosted UI (and therefore any authorization-code flow at all) does not exist
# without a domain on the pool — this is the resource that makes the authorize/token/logout
# endpoints reachable in the first place. Opt-in via hosted_ui_domain_prefix; a consumer doing
# only SRP auth needs none of this.
resource "aws_cognito_user_pool_domain" "primary" {
  count        = var.hosted_ui_domain_prefix != null ? 1 : 0
  domain       = var.hosted_ui_domain_prefix
  user_pool_id = aws_cognito_user_pool.primary.id
}

check "hosted_ui_domain_required_for_oauth" {
  assert {
    condition     = length(var.callback_urls) == 0 || var.hosted_ui_domain_prefix != null
    error_message = "hosted_ui_domain_prefix is required when callback_urls is set — AWS rejects an OAuth-enabled client on a pool with no Hosted UI domain."
  }
}

data "aws_region" "current" {}
