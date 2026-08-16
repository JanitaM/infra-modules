# cloudwatch

A CloudWatch metric alarm wired to a dedicated SNS topic, always encrypted at rest (`kms_master_key_id`, no opt-out — the AWS-managed `alias/aws/sns` key by default, or a customer-managed key via `kms_key_id`). Optionally subscribes an email address to the topic.

This module has no input for leaving the alert topic unencrypted. Encryption at rest is set unconditionally in the module; `policy/aws/modules/cloudwatch.rego` checks the plan itself, so it also catches an SNS topic someone writes by hand instead of through this module.

## Usage

```hcl
module "lambda_errors" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cloudwatch?ref=v1.0.0"

  alarm_name          = "example-api-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    FunctionName = module.api_handler.function_name
  }

  alert_email = "oncall@example.com"

  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `alarm_name` | Alarm name, also used to derive the SNS topic name | `string` | — (required) |
| `alarm_description` | Alarm description | `string` | `""` |
| `namespace` | Metric namespace, e.g. `AWS/Lambda` | `string` | — (required) |
| `metric_name` | Metric name, e.g. `Errors` | `string` | — (required) |
| `statistic` | `SampleCount`/`Average`/`Sum`/`Minimum`/`Maximum` | `string` | `"Sum"` |
| `period` | Evaluation period, in seconds | `number` | `300` |
| `evaluation_periods` | Number of periods compared to the threshold | `number` | `1` |
| `threshold` | Value the metric is compared against | `number` | — (required) |
| `comparison_operator` | `GreaterThanOrEqualToThreshold`/`GreaterThanThreshold`/`LessThanThreshold`/`LessThanOrEqualToThreshold` | `string` | — (required) |
| `dimensions` | Metric dimensions, e.g. `{ FunctionName = "..." }` | `map(string)` | `{}` |
| `treat_missing_data` | `missing`/`ignore`/`breaching`/`notBreaching` | `string` | `"missing"` |
| `alert_email` | Email address to subscribe to the alert topic | `string` | `null` |
| `kms_key_id` | KMS key ID/ARN to encrypt the alert topic with | `string` | `null` |
| `tags` | Tags applied to the alarm and its alert topic | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `alarm_arn` | Alarm ARN |
| `alarm_name` | Alarm name |
| `topic_arn` | Alert SNS topic ARN |

## What this module always does, with no opt-out

- Encrypts the alert SNS topic at rest (AWS-managed key by default, or a customer-managed key via `kms_key_id`)
- Wires both `alarm_actions` and `ok_actions` to the same topic, so alarm and recovery are both notified
