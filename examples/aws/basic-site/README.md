# basic-site

The full reference architecture: a static site plus an API, the "shape most small projects start from" (see `context/project-overview.md`, Build Order). Wires together every module in this repo except `iam-role` and `dynamodb-table` (see `../sessions-table` for that one) — a real, if minimal, static-site-with-an-API stack.

## What this builds

| Module | Purpose |
|---|---|
| `s3-bucket` | Static site storage, versioned |
| `lambda-function-url` (`api_handler`) | The API — reads the secret/parameter below and sends mail via SES |
| `cloudfront-distribution` | Public edge in front of both the bucket and the API, behind a WAF |
| `cognito` | User pool for the site |
| `ses` | Outbound mail domain |
| `route53` | DNS zone, plus the SES verification/DKIM records and an alias to the CloudFront distribution |
| `codebuild` | CI project for this site's own repo |
| `secrets-manager` (`api_key`) | Third-party API key the handler reads |
| `ssm` (`feature_flags`) | Feature flag config the handler reads |
| `cloudwatch` (`api_errors_alarm`) | Alarms on API handler errors, feeding the budget's SNS topic |
| `budget` | Monthly spend alert, notified by both email and the CloudWatch alarm's topic |

Plus a bare `aws_wafv2_web_acl` (empty rule set, default-allow) — CloudFront requires a WAF attached, so this example creates the minimum one that satisfies that; a real project attaches actual managed rule groups.

## Prerequisites

- Terraform >= 1.6
- The `archive` provider (`hashicorp/archive`, declared in `main.tf`'s `terraform` block) — zips `src/index.js` into `build/handler.zip` at plan time
- AWS credentials for the account you want to deploy into
- A registered domain if you intend to actually use the Route 53 zone and SES sending — the zone this creates needs its name servers delegated from your registrar to become live

## Using this as a starting point

Every domain name, email address, and resource name here (`example-basic-site.com`, `mail.example-basic-site.com`, `billing@example-basic-site.com`, the `example-basic-site*` prefixes) is a placeholder. Search-and-replace them with your own before deploying — nothing here resolves to a real domain you can use as-is.

`module.api_key`'s `secret_string = "placeholder-rotate-before-use"` is exactly that: a placeholder value the module creates so the secret container exists, meant to be rotated to a real value out-of-band (this module deliberately doesn't manage secret *values* long-term, only the container and read policy — see `modules/aws/secrets-manager`).

## State management

This example has no backend configured, so `terraform init` defaults to local state. Fine for trying it out; not for real use — see the root [README](../../../README.md#state-management) for the bootstrap steps before using this as a real starting point.

## Running it

```
terraform init
terraform plan
```

This repo's own CI only runs `terraform validate` against this example (no real AWS credentials in CI) — `plan`/`apply` require your own credentials and are on you to run.
