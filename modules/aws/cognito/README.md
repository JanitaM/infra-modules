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

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `user_pool_name` | Name of the Cognito user pool | `string` | — (required) |
| `client_name` | Name of the user pool client (app client) | `string` | `"app-client"` |
| `auto_verified_attributes` | Attributes Cognito auto-verifies; entries must be `email` or `phone_number` | `list(string)` | `["email"]` |
| `tags` | Tags applied to the user pool | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `user_pool_id` | User pool ID |
| `user_pool_arn` | User pool ARN |
| `user_pool_client_id` | App client ID |
| `user_pool_endpoint` | User pool endpoint, for constructing hosted-UI / token URLs |

## What this module always does, with no opt-out

- Requires MFA (`mfa_configuration = "ON"`) via software token — no password-only sign-in
- Enforces a 12-character minimum password with uppercase, lowercase, numbers, and symbols
- Creates the app client with no secret (`generate_secret = false`), suited to a browser or mobile client that can't keep one confidential
- Enables `prevent_user_existence_errors` so authentication responses don't reveal whether a given username exists
