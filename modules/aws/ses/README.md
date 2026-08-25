# ses

An SES domain identity with DKIM signing enabled, plus an IAM policy scoped to sending email through that identity only — no wildcard resource or action. Bounce/complaint monitoring (a configuration set + SNS event destination) is opt-in via `feedback_notification_email`/`existing_topic_arn`.

This module has no input for skipping DKIM or widening the sending policy beyond the one identity it creates. Domain ownership verification and DKIM still require adding the DNS records SES issues (see outputs) at your DNS provider — Terraform can't do that step for you unless the zone is also managed here (see the `route53` module, once it exists).

## Usage

```hcl
module "mail" {
  source = "github.com/JanitaM/infra-modules//modules/aws/ses?ref=v1.0.0"

  domain = "mail.example.com"

  # Optional: creates a configuration set + SNS topic + bounce/complaint
  # event destination, and subscribes this address to the topic. Leave unset
  # to skip all of it (no monitoring, matching pre-v1.16.0 behavior).
  feedback_notification_email = "ops@example.com"

  tags = {
    project = "example"
  }
}
```

Pass the module's `configuration_set_name` output to `SendEmailCommand`'s `ConfigurationSetName` — SES only fires bounce/complaint events for sends that reference the configuration set explicitly, and only fires them at all when the address behind `feedback_notification_email` has confirmed its SNS subscription (a confirmation email is sent on apply; nothing arrives until that link is clicked).

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `domain` | Domain to verify as an SES identity | `string` | — (required) |
| `tags` | Tags applied to the sending IAM policy, and to the bounce/complaint SNS topic when this module creates one | `map(string)` | `{}` |
| `feedback_notification_email` | Email address subscribed to bounce/complaint notifications. `null` skips the configuration set, topic, and event destination entirely | `string` | `null` |
| `existing_topic_arn` | Bounce/complaint topic to notify instead of creating one | `string` | `null` |
| `kms_key_id` | KMS key to encrypt the bounce/complaint SNS topic with. Ignored when `existing_topic_arn` is set | `string` | `null` (`alias/aws/sns`) |

## Outputs

| Name | Description |
|---|---|
| `domain_identity_arn` | SES domain identity ARN |
| `verification_token` | TXT record value for domain ownership verification |
| `dkim_tokens` | CNAME record values for DKIM signing |
| `send_policy_arn` | ARN of the IAM policy scoped to sending via this identity |
| `configuration_set_name` | Name of the bounce/complaint configuration set, `null` if neither feedback input is set |
| `topic_arn` | ARN of the bounce/complaint topic (created or reused), `null` if neither feedback input is set |

## What this module always does, with no opt-out

- Enables DKIM signing on the domain identity — outbound mail from this domain is always signed
- Scopes the sending IAM policy's `Resource` to this identity's ARN only, never `*`

## What's opt-in

- Bounce/complaint monitoring (configuration set, SNS topic, event destination) — set `feedback_notification_email` and/or `existing_topic_arn`, or get none of it, unlike DKIM and the sending policy above.
