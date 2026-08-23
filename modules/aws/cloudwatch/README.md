# cloudwatch

A CloudWatch metric alarm wired to an SNS topic, always encrypted at rest (`kms_master_key_id`, no opt-out — the AWS-managed `alias/aws/sns` key by default, or a customer-managed key via `kms_key_id`). Optionally subscribes an email address to the topic.

Two optional extras, both off by default:

- **Log-based alarms.** Set `log_group_name` + `log_filter_pattern` and the module also creates the `aws_cloudwatch_log_metric_filter` that produces the metric, published under the module's own `namespace`/`metric_name` — so one module instance is a coherent filter → metric → alarm → topic unit. Without this, alarming on a log line means hand-writing the filter next to the module and keeping its metric identifiers in sync with the alarm's by hand.
- **Shared topics.** Set `existing_topic_arn` (typically another instance's `topic_arn` output) and the module skips creating a topic, pointing the alarm at that one instead. Several alarms can then share one topic — and one email subscription confirmation.

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

### A log-based alarm sharing an existing topic

Counts a log line the application already emits, and notifies the topic the alarm above
created rather than minting a second one:

```hcl
module "email_send_failures" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cloudwatch?ref=v1.14.0"

  alarm_name        = "example-email-send-failures"
  alarm_description = "Alerts when a confirmation email fails to send."

  # The filter publishes this metric; the alarm watches it.
  namespace   = "Example/Web"
  metric_name = "EmailSendFailures"

  log_group_name     = "/aws/lambda/${module.api_handler.function_name}"
  log_filter_pattern = "\"Failed to send confirmation email\""

  statistic           = "Sum"
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  existing_topic_arn = module.lambda_errors.topic_arn

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
| `kms_key_id` | KMS key ID/ARN to encrypt the alert topic with (ignored when `existing_topic_arn` is set) | `string` | `null` |
| `existing_topic_arn` | Topic to notify instead of creating one, e.g. another instance's `topic_arn` | `string` | `null` |
| `log_group_name` | Log group to publish a metric from, making this a log-based alarm. Set with `log_filter_pattern` | `string` | `null` |
| `log_filter_pattern` | CloudWatch Logs filter pattern selecting the lines to count. Set with `log_group_name` | `string` | `null` |
| `tags` | Tags applied to the alarm and its alert topic | `map(string)` | `{}` |

`log_group_name` and `log_filter_pattern` must be set together — one names the log group, the other what to match in it. Setting only one fails the plan with an explicit message, via a precondition on the alarm (a precondition rather than a variable `validation` block because cross-variable validation needs Terraform >= 1.9, and this module floors at 1.7).

## Outputs

| Name | Description |
|---|---|
| `alarm_arn` | Alarm ARN |
| `alarm_name` | Alarm name |
| `topic_arn` | Alert SNS topic ARN — the created topic, or `existing_topic_arn` when passed |
| `log_metric_filter_name` | Log metric filter name, or `null` when no filter was requested |

## Upgrading to `v1.14.0`

`existing_topic_arn` gives `aws_sns_topic.alerts` a `count`, moving its address to `aws_sns_topic.alerts[0]`. The module ships a `moved` block for this, so upgrading is a state move with no plan diff — no destroy-and-recreate of a live topic, and existing email subscriptions keep working without a fresh confirmation click. No consumer action required.

## What this module always does, with no opt-out

- Encrypts the alert SNS topic at rest (AWS-managed key by default, or a customer-managed key via `kms_key_id`) — when it creates one; with `existing_topic_arn` the caller owns that guarantee, and the topic it points at is normally another instance of this module's
- Wires both `alarm_actions` and `ok_actions` to the same topic, so alarm and recovery are both notified
- Publishes a log-based metric under the same `namespace`/`metric_name` the alarm watches, so the two can never drift apart
