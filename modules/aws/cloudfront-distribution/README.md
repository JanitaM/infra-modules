# cloudfront-distribution

A CloudFront distribution fronting one or more origins from other modules in this repo — an `s3-bucket` (static content) and/or a `lambda-function-url` (API) — with Origin Access Control so those origins never need to be public themselves.

This module has no input for skipping the WAF web ACL or allowing plaintext HTTP to the viewer. It takes a bucket from the `s3-bucket` module and attaches the OAC bucket policy for you, and/or a function from the `lambda-function-url` module and grants CloudFront permission to invoke its `AWS_IAM`-only Function URL.

## Usage

```hcl
module "site" {
  source = "github.com/JanitaM/infra-modules//modules/aws/cloudfront-distribution?ref=v1.0.0"

  default_origin_id = "static-site"
  web_acl_arn        = aws_wafv2_web_acl.edge.arn

  origins = [
    {
      origin_id   = "static-site"
      origin_type = "s3"
      domain_name = module.site_bucket.bucket_regional_domain_name
      bucket_id   = module.site_bucket.bucket_id
      bucket_arn  = module.site_bucket.bucket_arn
    },
    {
      origin_id     = "api"
      origin_type   = "lambda"
      domain_name   = replace(replace(module.webhook_handler.function_url, "https://", ""), "/", "")
      function_name = module.webhook_handler.function_name
      path_pattern  = "/api/*"
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
| `origins` | Origins to attach. Exactly one must have `origin_id == default_origin_id`; every other origin needs `path_pattern` to be routable. Each entry: `origin_id`, `origin_type` (`s3` or `lambda`), `domain_name`, plus `bucket_id`/`bucket_arn` (s3) or `function_name` (lambda) | `list(object(...))` | — (required) |
| `default_origin_id` | `origin_id` used by the default cache behavior | `string` | — (required) |
| `web_acl_arn` | ARN of the WAFv2 web ACL (scope `CLOUDFRONT`) to attach | `string` | — (required) |
| `default_root_object` | Object returned for requests to the root URL | `string` | `"index.html"` |
| `price_class` | `PriceClass_100`, `PriceClass_200`, or `PriceClass_All` | `string` | `"PriceClass_100"` |
| `aliases` | Alternate domain names (CNAMEs) | `list(string)` | `[]` |
| `acm_certificate_arn` | ACM cert ARN (us-east-1), required when `aliases` is set | `string` | `null` |
| `default_cache_behavior_allowed_methods` | HTTP methods allowed on the default cache behavior | `list(string)` | `["GET", "HEAD"]` |
| `forwarded_headers` | Request headers to forward to the origin and cache on, for the default cache behavior only | `list(string)` | `[]` |
| `forwarded_query_string_keys` | Query string keys to forward and cache on, for the default cache behavior only. Non-empty does not mean "forward everything" — only these keys | `list(string)` | `[]` |
| `forwarded_cookie_names` | Cookie names to forward and cache on, for the default cache behavior only | `list(string)` | `[]` |
| `cache_policy_id` | ID of an `aws_cloudfront_cache_policy` to attach to every cache behavior, replacing `forwarded_values` (and its implicit legacy TTLs) entirely. Mutually exclusive with `forwarded_headers`/`forwarded_query_string_keys`/`forwarded_cookie_names`. This module doesn't author the policy itself | `string` | `null` |
| `origin_request_policy_id` | ID of an `aws_cloudfront_origin_request_policy` to attach to every cache behavior. Only meaningful alongside `cache_policy_id` | `string` | `null` |
| `response_headers_policy_id` | ID of an `aws_cloudfront_response_headers_policy` to attach to every cache behavior (e.g. for CSP/HSTS). This module doesn't author the policy itself — header content is project-specific | `string` | `null` |
| `tags` | Tags applied to the distribution | `map(string)` | `{}` |

### Cache-forwarding on the default behavior

By default the default cache behavior forwards nothing (matching every version of this module
before `forwarded_headers`/`forwarded_query_string_keys`/`forwarded_cookie_names` existed).
Setting any of the three switches that specific dimension on, scoped to exactly the
names/keys given — never "forward everything" on the default behavior, which stays the
`ordered_cache_behavior`s' job (each already forwards all query strings and cookies to its
own path-routed origin). This is enough to express, for example, a Next.js RSC caching
contract in front of a dynamic origin:

```hcl
forwarded_headers          = ["rsc"]
forwarded_query_string_keys = ["_rsc"]
forwarded_cookie_names      = ["__prerender_bypass"]
```

### Cache Policy / Origin Request Policy instead of legacy forwarding

Setting `cache_policy_id` replaces `forwarded_values` on every cache behavior entirely — AWS's
CloudFront API rejects a behavior with both set, and a `check` block in this module enforces
that `forwarded_headers`/`forwarded_query_string_keys`/`forwarded_cookie_names` stay empty
whenever `cache_policy_id` is set. This module doesn't create the policy itself (same as
`response_headers_policy_id`); create an `aws_cloudfront_cache_policy` (and optionally an
`aws_cloudfront_origin_request_policy`) alongside this module and pass their IDs in:

```hcl
cache_policy_id           = aws_cloudfront_cache_policy.example.id
origin_request_policy_id = aws_cloudfront_origin_request_policy.example.id
```

Some CloudFront pricing-plan tiers require moving off the legacy `forwarded_values`/implicit-TTL
behavior entirely — this is how to do that without hand-rolling the distribution.

## Outputs

| Name | Description |
|---|---|
| `distribution_id` | Distribution ID |
| `distribution_arn` | Distribution ARN |
| `domain_name` | `*.cloudfront.net` domain name |
| `hosted_zone_id` | Fixed CloudFront hosted zone ID, for a Route 53 alias record |

## What this module always does, with no opt-out

- Requires a WAF web ACL (`web_acl_id`) — no default, plan fails without one
- Forces `redirect-to-https` on every cache behavior — never plaintext HTTP to the viewer
- Uses Origin Access Control (never a public bucket or public Function URL) for every origin, and provisions the matching bucket policy / Lambda permissions itself — for a lambda origin, both `lambda:InvokeFunctionUrl` and `lambda:InvokeFunction` (AWS has required both since ~October 2025; OAC-signed requests get a 403 `AccessDeniedException` from the function URL with only the first, confirmed against real AWS)
- HTTPS-only, TLS 1.2+ from CloudFront to Lambda origins
