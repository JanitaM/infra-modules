# acm

Issues an ACM certificate. Validation is left to the caller: this module outputs `domain_validation_options` for DNS validation (the default), and doesn't create DNS records or an `aws_acm_certificate_validation` itself.

AWS only assigns a DNS validation record's name/value once the certificate exists, so a module that creates both the certificate and its validation records forces every caller into a two-phase `apply` on first create. Composing them at the root config instead keeps that AWS ordering constraint visible rather than hiding it behind this module.

CloudFront requires the certificate to exist in `us-east-1`, regardless of which region the rest of a project runs in. If the caller's default provider isn't `us-east-1`, pass this module a `us-east-1`-aliased provider.

## Usage

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "site_cert" {
  source = "github.com/JanitaM/infra-modules//modules/aws/acm?ref=v1.0.0"
  providers = {
    aws = aws.us_east_1
  }

  domain_name = "example.com"

  tags = {
    project = "example"
  }
}

resource "aws_route53_record" "site_cert_validation" {
  for_each = {
    for dvo in module.site_cert.domain_validation_options : dvo.domain_name => dvo
  }

  zone_id = module.dns.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "site_cert" {
  certificate_arn         = module.site_cert.certificate_arn
  validation_record_fqdns = [for r in aws_route53_record.site_cert_validation : r.fqdn]
}

module "site" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cloudfront-distribution?ref=v1.0.0"

  aliases             = ["example.com"]
  acm_certificate_arn = aws_acm_certificate_validation.site_cert.certificate_arn
  # ...
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `domain_name` | Primary domain name for the certificate | `string` | — (required) |
| `subject_alternative_names` | Additional domain names covered by the certificate | `list(string)` | `[]` |
| `validation_method` | `DNS` or `EMAIL` | `string` | `"DNS"` |
| `tags` | Tags applied to the certificate | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `certificate_arn` | The (possibly still-pending, until validated) certificate's ARN |
| `domain_validation_options` | DNS validation records to create, for DNS validation |

## What this module always does, with no opt-out

- `create_before_destroy` on the certificate — a replacement (e.g. adding a SAN) provisions the new cert before the old one is torn down
