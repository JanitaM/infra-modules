# route53

A public Route 53 hosted zone with DNSSEC signing enabled, plus optional alias records (for another module's DNS target, e.g. `cloudfront-distribution`'s `domain_name` + `hosted_zone_id`) and plain records (for domain/DKIM verification, e.g. the `ses` module's `verification_token` and `dkim_tokens` outputs).

This module has no input for skipping DNSSEC. It owns the zone; it doesn't create the resources records point at — pass in another module's outputs to wire them together.

## Usage

```hcl
module "dns" {
  source = "github.com/JanitaM/infra-modules//modules/aws/route53?ref=v1.0.0"

  domain_name = "example.com"

  alias_records = [
    {
      name                = ""
      type                = "A"
      target_domain_name  = module.site.domain_name
      target_zone_id      = module.site.hosted_zone_id
    },
  ]

  records = [
    {
      name   = "_amazonses.mail.example.com"
      type   = "TXT"
      values = [module.mail.verification_token]
    },
    {
      name   = module.mail.dkim_tokens[0]
      type   = "CNAME"
      values = ["${module.mail.dkim_tokens[0]}.dkim.amazonses.com"]
    },
  ]

  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `domain_name` | Domain name for the public hosted zone | `string` | — (required) |
| `alias_records` | Alias (A/AAAA) records pointing at another resource's DNS target. Each entry: `name`, `type` (`A` or `AAAA`), `target_domain_name`, `target_zone_id`, `evaluate_target_health` | `list(object(...))` | `[]` |
| `records` | Plain records (e.g. TXT/CNAME). Each entry: `name`, `type`, `ttl`, `values` | `list(object(...))` | `[]` |
| `tags` | Tags applied to the hosted zone and DNSSEC key | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `zone_id` | Hosted zone ID |
| `name_servers` | Name servers to configure at the domain registrar |

## What this module always does, with no opt-out

- Enables DNSSEC signing on the hosted zone via a dedicated asymmetric KMS key — zones are always tamper-evident, never unsigned
- Scopes the DNSSEC KMS key policy to the Route 53 service and this account only
