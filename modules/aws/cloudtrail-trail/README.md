# cloudtrail-trail

A CloudTrail trail plus the S3 bucket it logs to, wired together with the exact bucket policy
CloudTrail needs and nothing more. Builds the log bucket by composing this repo's own
`s3-bucket` module, so it inherits that module's always-blocked public access and always-on
encryption without re-implementing either.

This module does not decide where a consuming project applies it, or what to name the log
bucket — those are project-specific decisions. In particular, **name the bucket outside any
prefix a CI/deploy role already has broad S3 access to.** A bucket matching that prefix hands
the role being audited delete access to its own audit trail.

## Usage

```hcl
module "audit_trail" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cloudtrail-trail?ref=v1.11.0"

  trail_name  = "example-account-trail"
  bucket_name = "example-audit-logs-123456789012"
  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `trail_name` | Name of the CloudTrail trail | `string` | — (required) |
| `bucket_name` | Globally unique name for the log bucket this module creates | `string` | — (required) |
| `is_multi_region_trail` | Log events from every region | `bool` | `true` |
| `include_global_service_events` | Include IAM/STS and other global-service events | `bool` | `true` |
| `event_selector` | CloudTrail event selectors | `list(object(...))` | management events only, all read/write types |
| `kms_key_id` | ARN of an existing KMS key to encrypt log files with | `string` | `null` (SSE-S3 via the log bucket) |
| `tags` | Tags applied to the trail and its log bucket | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `trail_arn` | ARN of the trail |
| `trail_id` | ID of the trail |
| `bucket_id` | Log bucket name/ID |
| `bucket_arn` | Log bucket ARN |

## What this module always does, with no opt-out

- Enables CloudTrail log file validation, so tampering with delivered log files is detectable.
- Scopes the log bucket's policy to this specific trail's ARN (`SourceArn` condition on every
  statement) — the policy can't be reused to authorize any other trail.
- Blocks all public access and enables SSE-S3 encryption on the log bucket, via the `s3-bucket`
  module this module composes.

## What this module deliberately does not do

- Does not pick or default a bucket name — see the naming warning above.
- Does not create a KMS key. `kms_key_id` attaches an existing one; the module does not author
  or manage the key's lifecycle.
- Does not enable data event logging by default. `event_selector` defaults to management events
  only, which cost nothing extra and cover control-plane activity (who changed what). Data
  events (S3 object-level access, Lambda invocations, etc.) are billed per event — opt in
  explicitly by setting `data_resources` on an event selector.
- Does not wire CloudWatch Logs, metric filters, alarms, or SNS notification on log delivery.
  The trail is queryable via S3/Athena on its own; alerting is a natural follow-on, not part of
  standing up a trail.
- Does not set a lifecycle/retention policy on the log bucket — logs accumulate indefinitely at
  S3 Standard pricing unless the caller adds one.
