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
| `global_secondary_indexes` | Global secondary indexes — see below | `list(object({...}))` | `[]` |
| `ttl_attribute` | Attribute DynamoDB uses for item expiry (TTL) | `string` | `null` (disabled) |
| `tags` | Tags applied to the table | `map(string)` | `{}` |

### `global_secondary_indexes`

```hcl
global_secondary_indexes = [
  {
    name             = "status-index"
    hash_key         = "status"
    range_key        = "published_at"       # optional
    projection_type  = "ALL"                 # or "KEYS_ONLY" — INCLUDE is not supported
  },
]
```

Each entry's `hash_key`/`range_key` get their own table `attribute` block automatically —
don't redeclare them via the table's own `hash_key`/`range_key` inputs unless they're also the
table's own key (the module deduplicates either way, so reusing a key is safe).

## Outputs

| Name | Description |
|---|---|
| `table_id` | Table name/ID |
| `table_arn` | Table ARN |

## What this module always does, with no opt-out

- Enables point-in-time recovery
- Enables server-side encryption
