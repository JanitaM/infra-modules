# dynamodb-table

A DynamoDB table with point-in-time recovery and server-side encryption always on.

## Usage

```hcl
module "sessions_table" {
  source     = "github.com/JanitaM/infra-modules//modules/aws/dynamodb-table?ref=v1.0.0"
  table_name = "example-sessions"
  hash_key   = "session_id"
  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `table_name` | DynamoDB table name | `string` | — (required) |
| `hash_key` | Partition key attribute name | `string` | — (required) |
| `hash_key_type` | Partition key attribute type (`S`, `N`, `B`) | `string` | `"S"` |
| `range_key` | Sort key attribute name; leave empty for a hash-key-only table | `string` | `""` |
| `range_key_type` | Sort key attribute type (`S`, `N`, `B`) | `string` | `"S"` |
| `billing_mode` | `PAY_PER_REQUEST` or `PROVISIONED` | `string` | `"PAY_PER_REQUEST"` |
| `tags` | Tags applied to the table | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `table_id` | Table name/ID |
| `table_arn` | Table ARN |

## What this module always does, with no opt-out

- Enables point-in-time recovery
- Enables server-side encryption
