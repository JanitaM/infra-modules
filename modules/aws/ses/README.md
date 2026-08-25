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

When `kms_key_id` is left unset, the module creates its own customer-managed KMS key for the topic rather than using the AWS-managed `alias/aws/sns` key. This isn't a preference — it's the only option that works. AWS does not let a customer edit an AWS-managed key's policy at all, so there is no way to grant SES the `kms:GenerateDataKey`/`kms:Decrypt` it needs to publish into a topic encrypted with `alias/aws/sns` (confirmed live: `aws_ses_event_destination` fails with `InvalidSNSDestination: Access denied to KMS key ...` against that key, on every attempt). Pass your own `kms_key_id` only if you already have a key with the right policy (e.g. reusing one across services) — the module won't add SES's permissions to a key you supply.

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `domain` | Domain to verify as an SES identity | `string` | — (required) |
| `tags` | Tags applied to the sending IAM policy, and to the bounce/complaint SNS topic when this module creates one | `map(string)` | `{}` |
| `feedback_notification_email` | Email address subscribed to bounce/complaint notifications. `null` skips the configuration set, topic, and event destination entirely | `string` | `null` |
| `existing_topic_arn` | Bounce/complaint topic to notify instead of creating one | `string` | `null` |
| `kms_key_id` | KMS key to encrypt the bounce/complaint SNS topic with. Leave `null` to have the module create its own customer-managed key — see below. Ignored when `existing_topic_arn` is set | `string` | `null` |

## Outputs

| Name | Description |
|---|---|
| `domain_identity_arn` | SES domain identity ARN |
| `verification_token` | TXT record value for domain ownership verification |
| `dkim_tokens` | CNAME record values for DKIM signing |
| `send_policy_arn` | ARN of the IAM policy scoped to sending via this identity |
| `configuration_set_name` | Name of the bounce/complaint configuration set, `null` if neither feedback input is set |
| `topic_arn` | ARN of the bounce/complaint topic (created or reused), `null` if neither feedback input is set |
| `kms_key_arn` | ARN of the customer-managed key this module created for the topic, `null` if `kms_key_id`/`existing_topic_arn` was supplied instead, or neither feedback input is set |

## What this module always does, with no opt-out

- Enables DKIM signing on the domain identity — outbound mail from this domain is always signed
- Scopes the sending IAM policy's `Resource` to this identity's ARN only, never `*`

## What's opt-in

- Bounce/complaint monitoring (configuration set, SNS topic, event destination) — set `feedback_notification_email` and/or `existing_topic_arn`, or get none of it, unlike DKIM and the sending policy above.
