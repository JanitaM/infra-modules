# ssm

An SSM Parameter Store parameter, always encrypted (`SecureString`, no opt-out), plus a scoped IAM policy (`read_policy_arn`) that consumers attach to their own roles to grant `ssm:GetParameter`/`GetParameters` on this parameter's ARN and `kms:Decrypt` on its encryption key only — never a wildcard resource.

This module has no input for using `String` or `StringList` instead. A plaintext parameter is readable by anyone with `ssm:GetParameter` alone — no KMS decrypt permission required — so `SecureString` is the only type this module creates.

## Usage

```hcl
module "api_key" {
  source = "github.com/JanitaM/infra-modules//modules/aws/ssm?ref=v1.0.0"

  parameter_name = "/example/api-key"
  value          = var.api_key

  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `parameter_name` | Parameter name (supports `/` as a path separator) | `string` | — (required) |
| `description` | Parameter description | `string` | `""` |
| `value` | Parameter value | `string` | — (required) |
| `kms_key_id` | KMS key ID/ARN to encrypt with. Defaults to the AWS-managed `alias/aws/ssm` key | `string` | `null` |
| `tier` | `Standard`, `Advanced`, or `Intelligent-Tiering` | `string` | `"Standard"` |
| `tags` | Tags applied to the parameter and its read policy | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `parameter_name` | Parameter name |
| `parameter_arn` | Parameter ARN |
| `version` | Parameter version |
| `read_policy_arn` | ARN of the scoped read-only IAM policy for consumers to attach |

## What this module always does, with no opt-out

- Creates the parameter as `SecureString`, never plaintext `String`/`StringList`
- Encrypts with the AWS-managed key by default, or a customer-managed key via `kms_key_id`
- Exposes a read-only IAM policy scoped to this parameter's exact ARN and its encryption key, never a wildcard resource
