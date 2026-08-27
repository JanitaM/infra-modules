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
      qualifier     = module.webhook_handler.alias_arn != null ? "live" : null # only set alongside a Function URL that itself targets an alias/version
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
| `origins` | Origins to attach. Exactly one must have `origin_id == default_origin_id`; every other origin needs `path_pattern` to be routable. Each entry: `origin_id`, `origin_type` (`s3` or `lambda`), `domain_name`, plus `bucket_id`/`bucket_arn` (s3) or `function_name` (lambda), plus optional per-origin `cache_policy_id`/`origin_request_policy_id`/`response_headers_policy_id` (ordered cache behaviors only — override the module-level vars of the same name for that one origin's behavior; fall back to them when unset) and `qualifier` (lambda only — alias name or version the CloudFront-invoke permission is scoped to; `null` grants on the unqualified ARN/`$LATEST`, matching this module's original behavior; set it to whatever qualifier the origin's Function URL itself targets, e.g. `lambda-function-url`'s own `qualifier` variable, or CloudFront gets a 403 invoking an alias the permission doesn't cover). An origin may repeat another origin's `domain_name`/`function_name` under a distinct `origin_id` to give one more `path_pattern` on the same underlying origin its own cache policy without a second module instance | `list(object(...))` | — (required) |
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
| `lambda_edge_origin_request_arn` | Qualified ARN (including a published version — CloudFront rejects `$LATEST` for Lambda@Edge) of a Lambda@Edge function to associate with the `origin-request` event, `include_body = true`, on every lambda-type origin's cache behavior (default and ordered alike). Not attached to s3-type origins' behaviors | `string` | `null` |
| `viewer_request_function_arn` | ARN of an `aws_cloudfront_function` to associate with the `viewer-request` event on every cache behavior (default and ordered alike), regardless of origin type | `string` | `null` |
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

### Lambda@Edge on `origin-request`, for OAC-signed lambda origins

CloudFront's OAC signs a lambda-type origin's request with SigV4, but never computes the
request body's payload hash itself — [AWS documents this as by
design](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-lambda.html),
pushing the `x-amz-content-sha256` header onto whoever issues the request. That's workable for
a caller you author yourself (a `fetch` call can set the header), and not workable for a caller
you don't control the internals of (e.g. a framework's own request-issuing runtime).
`lambda_edge_origin_request_arn` attaches a Lambda@Edge function to `origin-request` — which
runs *before* CloudFront's OAC signs the request to the origin — so it can compute
`x-amz-content-sha256` from the body and set the header for every caller uniformly, without
weakening `AWS_IAM` auth or OAC's `signing_behavior = "always"` on the origin itself. This
module doesn't author the Lambda@Edge function — create it (published in `us-east-1`, since
Lambda@Edge requires that region) and pass its qualified ARN in:

```hcl
lambda_edge_origin_request_arn = aws_lambda_function.content_hash_signer.qualified_arn
```

Lambda@Edge's `origin-request`/`origin-response` triggers cap request-body access at ~1MB when
`include_body` is enabled (always on here); a body larger than that arrives truncated to the
function. Confirm actual payload sizes for your origin's POST/PUT/PATCH traffic before relying
on this for a body that could exceed it.

### CloudFront Function on `viewer-request`, for logic that must run before origin selection

`viewer_request_function_arn` attaches an `aws_cloudfront_function` to the `viewer-request`
event — CloudFront's earliest hook, running before it has decided which origin/cache behavior
even applies. Use this for cheap, stateless per-request logic like a host-based redirect (e.g.
`www` to apex): a Lambda@Edge `origin-request` function (`lambda_edge_origin_request_arn`
above) runs too late for this, since CloudFront has already committed to fetching from the
origin by then. Unlike `lambda_edge_origin_request_arn`, this attaches to every cache
behavior's default *and* ordered form regardless of `origin_type` — a viewer-request check has
nothing to do with which origin the request would otherwise reach. This module doesn't author
the function itself:

```hcl
resource "aws_cloudfront_function" "www_redirect" {
  name    = "example-www-redirect"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("${path.module}/functions/www-redirect.js")
}

module "site" {
  # ...
  viewer_request_function_arn = aws_cloudfront_function.www_redirect.arn
}
```

CloudFront Functions only support JavaScript (a strict subset, no npm dependencies) and cap
execution at ~1ms — not a substitute for `lambda_edge_origin_request_arn` when the logic needs
Node.js, external calls, or more compute.

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
