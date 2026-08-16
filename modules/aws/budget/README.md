# budget

An AWS Budget with a mandatory notification. `alert_emails` has no default and must be non-empty, so a budget can never be created without a way to find out it was breached — a budget nobody gets notified about is just a number nobody looks at.

An SNS topic can be notified alongside email, e.g. the `topic_arn` output of the [cloudwatch](../cloudwatch/README.md) module, so budget alerts land in the same alerting pipeline as metric alarms.

## Usage

```hcl
module "monthly_budget" {
  source = "github.com/JanitaM/infra-modules//modules/aws/budget?ref=v1.0.0"

  budget_name           = "example-monthly"
  limit_amount          = "200.0"
  threshold_percentage  = 80
  alert_emails          = ["billing@example.com"]

  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `budget_name` | Budget name | `string` | — (required) |
| `limit_amount` | Spend limit, as a decimal string | `string` | — (required) |
| `limit_unit` | Currency for `limit_amount` | `string` | `"USD"` |
| `time_unit` | `DAILY`/`MONTHLY`/`QUARTERLY`/`ANNUALLY` | `string` | `"MONTHLY"` |
| `alert_emails` | Notified email addresses. Must be non-empty | `list(string)` | — (required) |
| `sns_topic_arn` | Additional SNS topic notified alongside email | `string` | `null` |
| `threshold_percentage` | Percentage of `limit_amount` that triggers notification | `number` | `80` |
| `comparison_operator` | `GREATER_THAN`/`LESS_THAN`/`EQUAL_TO` | `string` | `"GREATER_THAN"` |
| `notification_type` | `ACTUAL` or `FORECASTED` spend | `string` | `"ACTUAL"` |
| `tags` | Tags applied to the budget | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `budget_id` | Budget ID |
| `budget_name` | Budget name |
| `budget_arn` | Budget ARN |

## What this module always does, with no opt-out

- Requires at least one notification subscriber (`alert_emails`) — there is no way to create a budget with no one notified
