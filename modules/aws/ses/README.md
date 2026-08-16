# ses

An SES domain identity with DKIM signing enabled, plus an IAM policy scoped to sending email through that identity only — no wildcard resource or action.

This module has no input for skipping DKIM or widening the sending policy beyond the one identity it creates. Domain ownership verification and DKIM still require adding the DNS records SES issues (see outputs) at your DNS provider — Terraform can't do that step for you unless the zone is also managed here (see the `route53` module, once it exists).

## Usage

```hcl
module "mail" {
  source = "github.com/JanitaM/infra-modules//modules/aws/ses?ref=v1.0.0"

  domain = "mail.example.com"

  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `domain` | Domain to verify as an SES identity | `string` | — (required) |
| `tags` | Tags applied to the sending IAM policy | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `domain_identity_arn` | SES domain identity ARN |
| `verification_token` | TXT record value for domain ownership verification |
| `dkim_tokens` | CNAME record values for DKIM signing |
| `send_policy_arn` | ARN of the IAM policy scoped to sending via this identity |

## What this module always does, with no opt-out

- Enables DKIM signing on the domain identity — outbound mail from this domain is always signed
- Scopes the sending IAM policy's `Resource` to this identity's ARN only, never `*`
