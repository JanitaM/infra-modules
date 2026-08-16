# secrets-manager

A Secrets Manager secret, optionally seeded with an initial value, plus a scoped IAM policy (`read_policy_arn`) that consumers attach to their own roles to grant `secretsmanager:GetSecretValue`/`DescribeSecret` on this secret's ARN only — never a wildcard resource.

The secret has no resource policy by default, which means it's reachable only via a caller's own IAM permissions (e.g. the `read_policy_arn` output attached to a role). A resource policy is opt-in via `resource_policy_json`, for cases like cross-account access — but it can never grant a wildcard (`*`) principal; see `policy/aws/modules/secrets-manager.rego`.

## Usage

```hcl
module "db_password" {
  source = "github.com/JanitaM/infra-modules//modules/aws/secrets-manager?ref=v1.0.0"

  secret_name   = "example/db-password"
  secret_string = var.db_password

  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `secret_name` | Secret name (supports `/` as a path separator) | `string` | — (required) |
| `description` | Secret description | `string` | `""` |
| `kms_key_id` | KMS key ID/ARN to encrypt with. Defaults to the AWS-managed `aws/secretsmanager` key | `string` | `null` |
| `secret_string` | Initial secret value | `string` | `null` |
| `recovery_window_in_days` | Deleted-secret recovery window: `0` or `7`-`30` | `number` | `30` |
| `resource_policy_json` | IAM resource policy JSON, e.g. for cross-account access. Must not grant a wildcard principal | `string` | `null` |
| `tags` | Tags applied to the secret and its read policy | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `secret_id` | Secret ID |
| `secret_arn` | Secret ARN |
| `secret_name` | Secret name |
| `read_policy_arn` | ARN of the scoped read-only IAM policy for consumers to attach |

## What this module always does, with no opt-out

- Encrypts the secret at rest (AWS-managed key by default, or a customer-managed key via `kms_key_id`)
- Creates no resource policy unless one is explicitly passed in — a secret defaults to private
- Any resource policy that is attached is checked at plan time and must never grant a wildcard principal
- Exposes a read-only IAM policy scoped to this secret's exact ARN, never a wildcard resource
