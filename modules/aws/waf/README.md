# waf

A WAFv2 web ACL — generic across consumers, since `infra-modules` is shared across projects. It takes no project-specific concept (no URL path, hostname, or project name) as a first-class variable; `rate_based_rules[].uri_path_prefix` is the only path-shaped input, and it's structural (a generic list of rules), not a named single-purpose variable.

Typically attached to a `cloudfront-distribution`'s `web_acl_arn`, or to a REGIONAL resource (ALB, API Gateway) via `scope = "REGIONAL"`.

## Usage

```hcl
module "waf" {
  source = "github.com/JanitaM/infra-modules//modules/aws/waf?ref=v1.0.0"

  web_acl_name = "example-edge"

  rate_based_rules = [
    {
      name  = "api-rate-limit"
      limit = 2000
      uri_path_prefix = "/api/"
    },
  ]

  ip_allowlist = ["203.0.113.0/24"]

  tags = {
    project = "example"
  }
}

module "site" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cloudfront-distribution?ref=v1.0.0"

  web_acl_arn = module.waf.web_acl_arn
  # ...
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `web_acl_name` | Name for the web ACL (and its IP set, if `ip_allowlist` is set) | `string` | — (required) |
| `scope` | `CLOUDFRONT` or `REGIONAL` | `string` | `"CLOUDFRONT"` |
| `default_action` | `allow` or `block` for requests matching no rule | `string` | `"allow"` |
| `rate_based_rules` | Rate limits per source IP, optionally scoped to a `uri_path_prefix`. Each entry: `name`, `limit`, `evaluation_window_sec` (default `300`), `uri_path_prefix` (optional), `action` (`allow`/`block`/`count`, default `"block"`) | `list(object(...))` | `[]` |
| `ip_allowlist` | IPv4 CIDRs to allow; every other source is blocked | `list(string)` | `null` |
| `enable_logging` | Whether the web ACL logs to CloudWatch. Set `false` where the target CloudFront pricing tier doesn't include WAF access logs (e.g. Free) | `bool` | `true` |
| `tags` | Tags applied to the web ACL and its IP set | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `web_acl_arn` | Web ACL ARN — wire into `cloudfront-distribution`'s `web_acl_arn` or a REGIONAL resource's `web_acl_id` |
| `web_acl_id` | Web ACL ID |

## What this module always does, with no opt-out

- Reports CloudWatch metrics for the web ACL and every rule — see `policy/aws/modules/waf.rego`
- Includes the AWS-managed `AWSManagedRulesKnownBadInputsRuleSet` rule group (covers Log4Shell/CVE-2021-44228 request signatures, among other known-bad-input patterns), at priority `1`
- When `ip_allowlist` is set, enforces it at priority `0` (evaluated first, before every other rule, including the managed rule group), regardless of `default_action`

By default (`enable_logging = true`) this module also logs every request to a
`aws-waf-logs-<web_acl_name>` CloudWatch Logs group; set `enable_logging = false` to skip both
that log group and the logging configuration entirely.
