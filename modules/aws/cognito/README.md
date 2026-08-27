# cognito

A Cognito user pool for managed user identity, plus a public app client for a web or mobile front end to authenticate against.

This module has no input for disabling MFA or weakening the password policy — every user pool it creates requires a software token (TOTP) second factor and a 12-character minimum password with mixed case, numbers, and symbols.

## Usage

```hcl
module "users" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cognito?ref=v1.0.0"

  user_pool_name = "example-users"
  client_name    = "example-web-client"

  tags = {
    project = "example"
  }
}
```

For an OIDC/OAuth2 login flow (an app redirecting to Cognito's Hosted UI rather than calling SRP directly), also set `hosted_ui_domain_prefix` and `callback_urls`:

```hcl
module "users" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cognito?ref=v1.5.0"

  user_pool_name = "example-users"
  client_name    = "example-web-client"

  hosted_ui_domain_prefix = "example-app-auth" # must be globally unique across all AWS accounts
  callback_urls           = ["https://example.com/api/auth/callback"]
  logout_urls             = ["https://example.com/"]

  tags = {
    project = "example"
  }
}
```

To enable refresh-token rotation (each redeemed refresh token is replaced with a new one, and reuse of an already-rotated-out token becomes detectable — the default leaves refresh tokens static/reusable for their full validity):

```hcl
module "users" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cognito?ref=v1.6.0"

  user_pool_name = "example-users"
  client_name    = "example-web-client"

  refresh_token_rotation = {
    feature                    = "ENABLED"
    retry_grace_period_seconds = 0
  }

  tags = {
    project = "example"
  }
}
```

Build the OIDC endpoints from the module's outputs:

- `issuer` = `https://cognito-idp.<region>.amazonaws.com/${user_pool_id}`
- `authorization_endpoint` = `https://${hosted_ui_domain}/oauth2/authorize`
- `token_endpoint` = `https://${hosted_ui_domain}/oauth2/token`
- `jwks_uri` = `${issuer}/.well-known/jwks.json`
- `logout_endpoint` = `https://${hosted_ui_domain}/logout`
- `revoke_endpoint` = `https://${hosted_ui_domain}/oauth2/revoke`

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `user_pool_name` | Name of the Cognito user pool | `string` | — (required) |
| `client_name` | Name of the user pool client (app client) | `string` | `"app-client"` |
| `auto_verified_attributes` | Attributes Cognito auto-verifies; entries must be `email` or `phone_number` | `list(string)` | `["email"]` |
| `tags` | Tags applied to the user pool | `map(string)` | `{}` |
| `hosted_ui_domain_prefix` | Prefix for the Cognito-hosted domain that makes the Hosted UI's authorize/token/logout endpoints exist at all. Must be globally unique across all AWS accounts. `null` creates no domain | `string` | `null` |
| `callback_urls` | Allowed OAuth2 redirect URIs. Non-empty turns on the app client's authorization-code flow; requires `hosted_ui_domain_prefix` to be set | `list(string)` | `[]` |
| `logout_urls` | Allowed post-logout redirect URIs. Only meaningful when `callback_urls` is set | `list(string)` | `[]` |
| `allowed_oauth_scopes` | OAuth scopes granted to the authorization-code flow. Only meaningful when `callback_urls` is set | `list(string)` | `["openid", "email", "profile"]` |
| `refresh_token_rotation` | Refresh-token rotation for the app client (`feature` = `"ENABLED"` or `"DISABLED"`, `retry_grace_period_seconds` optional). `null` omits the block, keeping refresh tokens static/reusable | `object({ feature = string, retry_grace_period_seconds = optional(number, 0) })` | `null` |

## Outputs

| Name | Description |
|---|---|
| `user_pool_id` | User pool ID |
| `user_pool_arn` | User pool ARN |
| `user_pool_client_id` | App client ID |
| `user_pool_endpoint` | User pool endpoint, for constructing hosted-UI / token URLs |
| `hosted_ui_domain` | Hosted UI's base domain (`null` unless `hosted_ui_domain_prefix` is set) — build `authorize`/`token`/`logout` URLs from it as shown above |

## What this module always does, with no opt-out

- Requires MFA (`mfa_configuration = "ON"`) via software token — no password-only sign-in
- Enforces a 12-character minimum password with uppercase, lowercase, numbers, and symbols
- Creates the app client with no secret (`generate_secret = false`), suited to a browser or mobile client that can't keep one confidential
- Enables `prevent_user_existence_errors` so authentication responses don't reveal whether a given username exists
