# Changelog

All notable changes to this project are documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.8.0] - 2026-08-19

### Added

- `cache_policy_id` and `origin_request_policy_id` on `modules/aws/cloudfront-distribution`. The default and ordered cache behaviors previously always used the legacy `forwarded_values` block with no way to attach a modern Cache Policy / Origin Request Policy instead, and never set `min_ttl`/`default_ttl`/`max_ttl`, so AWS's legacy TTL defaults applied implicitly — a real consumer's CloudFront distribution was blocked from confirming *any* flat-rate pricing-plan tier (Free included) by AWS's tier-eligibility check, which flags `ForwardedValues`/legacy cache settings as unsupported (confirmed against AWS's own flat-rate-pricing-plan docs and the consumer's live distribution via `aws cloudfront get-distribution-config`). Setting `cache_policy_id` now drops `forwarded_values` entirely (AWS rejects a behavior with both set — enforced by a new `check` block) in favor of the policy's own TTLs and forwarding rules. Both default to `null`, matching the module's original hardcoded `forwarded_values`-based behavior, so existing consumers are unaffected. As with `response_headers_policy_id`, this module doesn't author the policy content itself — the caller creates the `aws_cloudfront_cache_policy`/`aws_cloudfront_origin_request_policy` resources and passes in their IDs.
- `enable_logging` on `modules/aws/waf`. WAF access logging was previously always on with no opt-out; AWS's flat-rate-pricing-plan tier documentation lists WAF request logs as a Pro-tier-and-above feature, so a web ACL with unconditional logging blocks Free-tier eligibility for its CloudFront distribution. Defaults to `true`, matching the module's original hardcoded behavior, so existing consumers are unaffected. Surfaced by the same real consumer's tier-eligibility investigation as the cache-policy change above — both gaps were confirmed live against the same blocked distribution.

Investigated but deliberately left unchanged: the same consumer's tier-eligibility check also flags a `byte_match_statement` scope-down statement on a rate-based rule ("byte match"). AWS's official flat-rate-pricing-plan docs (both the "Unsupported features" and "Features by pricing plan tier" tables) don't mention byte-match, scope-down statements, or rate-based rules at all, so there's no documented basis for picking an alternative statement type or for concluding lower tiers disallow scope-down statements entirely — either would be a guess. No code change is made here; the consumer should retest tier eligibility after adopting the two changes above (which should clear 4 of the 5 flagged items) to isolate whether "byte match" is still blocking before this gets its own follow-up.

## [1.7.0] - 2026-08-18

### Fixed

- `modules/aws/cloudfront-distribution` now grants `lambda:InvokeFunction` in addition to `lambda:InvokeFunctionUrl` on a lambda origin's resource policy. AWS has required both since ~October 2025 for CloudFront's OAC-signed requests to a Function URL to succeed — with only `InvokeFunctionUrl` (this module's prior behavior, and AWS's own long-documented pattern before that change), every request gets a 403 `AccessDeniedException` straight from the function URL itself, confirmed against a real, freshly-created distribution. Existing consumers get the added permission on their next apply — strictly additive, nothing removed.

## [1.6.0] - 2026-08-18

### Added

- `invoke_mode` on `modules/aws/lambda-function-url`. The Function URL previously had no way to opt into `RESPONSE_STREAM` — always `BUFFERED` by omission, AWS's own default — so a proxied app that streams its own response (e.g. via the Lambda Web Adapter's `AWS_LWA_INVOKE_MODE` env var) could set that adapter-level flag and still get buffered delivery, since the Function URL resource itself is a separate, required switch the adapter's env var doesn't reach. Defaults to `"BUFFERED"`, matching the module's original hardcoded behavior, so existing consumers are unaffected. Surfaced by a real consumer whose Lambda Web Adapter streaming behavior was already verified end-to-end via Docker/RIE, only to find the same streaming had no way to be requested from this module for the real Function URL.

## [1.5.0] - 2026-08-18

### Added

- `hosted_ui_domain_prefix`, `callback_urls`, `logout_urls`, and `allowed_oauth_scopes` on `modules/aws/cognito`, plus a `hosted_ui_domain` output. The module previously created a user pool client capable only of direct SRP auth — no Cognito-hosted domain, and the client had no OAuth2 settings — so a consumer wanting an authorization-code/Hosted UI login flow (an app redirecting to Cognito rather than calling SRP itself) had nothing to point its OIDC config at. All four inputs default to off/empty, matching the module's original SRP-only behavior; a new `check` block rejects `callback_urls` set without `hosted_ui_domain_prefix`, since AWS itself rejects an OAuth-enabled client on a pool with no Hosted UI domain. Surfaced by a real consumer's `apps/admin` expecting a full `authorizationEndpoint`/`tokenEndpoint`/`logoutEndpoint`/`revokeEndpoint` OIDC config against a pool this module had already created with none of that wired up.

## [1.4.0] - 2026-08-18

### Added

- `default_cache_behavior_allowed_methods` on `modules/aws/cloudfront-distribution`. The default cache behavior previously hardcoded `allowed_methods = ["GET", "HEAD"]`, so no consumer could route write methods (POST/PUT/PATCH/DELETE) through the default behavior — e.g. proxying an API through CloudFront on the default path. Defaults to `["GET", "HEAD"]`, matching the module's original hardcoded behavior, so existing consumers are unaffected. `cached_methods` stays hardcoded to `["GET", "HEAD"]` regardless of this setting, since CloudFront never caches responses to write methods.

## [1.3.0] - 2026-08-18

### Added

- `forwarded_headers`, `forwarded_query_string_keys`, `forwarded_cookie_names`, and `response_headers_policy_id` on `modules/aws/cloudfront-distribution`. The default cache behavior previously hardcoded `forwarded_values { query_string = false, cookies { forward = "none" } }` with no way to forward any header, and had no way to attach a Response Headers Policy at all — both generic CloudFront capabilities any dynamic origin can need (auth cookies, locale headers, A/B-test cookies, CSP/HSTS), not specific to any one consumer's use case. All four default to the module's original hardcoded behavior (forward/attach nothing), so existing consumers are unaffected. `response_headers_policy_id` takes an ID the caller creates elsewhere — this module still authors no header *content*, since CSP directives are inherently project-specific. Surfaced by a real consumer needing to forward a specific header/query-key/cookie for Next.js RSC caching and hand-rolling the whole distribution as a stopgap, only to still be blocked on Response Headers Policy separately.
- `global_secondary_indexes` and `ttl_attribute` on `modules/aws/dynamodb-table` — the module previously supported only a table's own hash/range key, forcing every GSI- or TTL-needing consumer to hand-roll `aws_dynamodb_table` instead. Both are generic DynamoDB capabilities, not project-specific: `global_secondary_indexes` is a `list(object({ name, hash_key, hash_key_type, range_key, range_key_type, projection_type }))` (`INCLUDE` projection is not supported — it needs a `non_key_attributes` list this module doesn't yet expose), and `ttl_attribute` is an optional attribute name. A GSI reusing the table's own hash/range key does not produce a duplicate `attribute` block. Surfaced by a real consumer needing 4 of 7 tables to have a GSI or TTL and hand-rolling all 4 as a stopgap.
- `layers` on `modules/aws/lambda-function-url` — attaches published or custom Lambda layer ARNs (e.g. the AWS Lambda Web Adapter extension layer, an X-Ray or monitoring agent layer). Generic Lambda capability the module previously had no way to express, capped at 5 entries matching AWS's own per-function limit. Surfaced by a real consumer needing the LWA layer for two functions and having to hand-roll `aws_lambda_function`/`aws_iam_role` as a stopgap.

## [1.2.0] - 2026-08-18

### Added

- `modules/aws/waf`, plus `policy/aws/modules/waf.rego`'s rule requiring CloudWatch metrics on the web ACL. Generic across consumers — `scope`, `default_action`, `rate_based_rules`, and `ip_allowlist` are the only inputs, no project-specific concept. Also hardcodes an `AWSManagedRulesKnownBadInputsRuleSet` managed rule group and CloudWatch Logs logging. `examples/aws/basic-site` now uses it in place of its hand-rolled `aws_wafv2_web_acl`.
- `modules/aws/acm`, plus `policy/aws/modules/acm.rego`'s rule forbidding `EMAIL` validation. Issues the certificate only — `domain_validation_options` is output for the caller to wire into DNS records and an `aws_acm_certificate_validation` at the root config, since a self-validating design would force every caller into a two-phase `apply` on first create (AWS doesn't assign a validation record's name/value until the certificate exists).
- `README.md` — "Requirements", "Contributing", and "License" sections, closing gaps found in a documentation audit: no prerequisites list, the branch-protection workflow written down nowhere a reader would find it, and no mention of the MIT license.
- `README.md` — "State management" section: this repo doesn't provision Terraform state storage, so this documents the bootstrap pattern (use `modules/aws/s3-bucket` for the state bucket, native S3 backend locking, `terraform init -migrate-state`) so consumers don't default to unlocked local state in production. Each of the 3 examples now links to it instead of defaulting silently.
- `SECURITY.md` — private vulnerability reporting via GitHub's Security tab, scope, and response expectations for this solo-maintainer repo.

### Changed

- CI now installs a pinned `conftest` release instead of always-latest, matching the existing `checkov` pin — same reasoning: an unpinned tool version can't silently change what CI enforces.

## [1.1.0] - 2026-08-17

### Added

- `additional_policy_arns` on `modules/aws/lambda-function-url` — attaches existing scoped policies to the function's execution role, in addition to the CloudWatch Logs baseline. `examples/aws/basic-site` now wires `api_handler` to the `api_key`/`feature_flags`/`mail` modules' policy ARNs, which previously had no consumer in the example.
- `.github/dependabot.yml` — weekly checks for GitHub Actions version bumps.
- `checkov` CI job plus `.checkov.yaml` — a real blocking static-analysis gate against `modules/aws`, alongside the curated `policy/aws` rego rules. Every skipped check is individually justified in `.checkov.yaml`. See `README.md`'s "Static analysis" section.
- MIT `LICENSE`.
- READMEs for all 3 examples (`basic-site`, `webhook-handler`, `sessions-table`) — what each builds, prerequisites, placeholder values to replace, and how to run it.

## [1.0.0] - 2026-08-16

### Added

- `modules/aws/s3-bucket` and `policy/aws/global.rego`'s "no public S3" rule — the first module and the first policy, proving the module → plan → policy pipeline end to end.
- `modules/aws/dynamodb-table`, plus `global.rego` rules requiring encryption at rest and point-in-time recovery. `examples/aws/sessions-table` shows it standalone.
- `modules/aws/lambda-function-url`, plus a rule requiring `AWS_IAM` authorization (never a public function URL). `examples/aws/webhook-handler` shows it standalone.
- `modules/aws/cloudfront-distribution`, plus a rule requiring a WAF web ACL on the distribution.
- `modules/aws/cognito`, plus a rule requiring MFA on the user pool.
- `modules/aws/ses`, plus `global.rego`'s "no wildcard IAM action/resource" rule (shared across every module that authors an IAM policy document).
- `modules/aws/route53`, plus a rule requiring DNSSEC signing on public hosted zones.
- `modules/aws/codebuild`, plus a rule forbidding `environment.privileged_mode`.
- `modules/aws/secrets-manager`, plus a rule forbidding a wildcard principal in the resource policy.
- `modules/aws/ssm`, plus a rule requiring parameter type `SecureString`.
- `modules/aws/cloudwatch` (SNS topic), plus a rule requiring `kms_master_key_id`.
- `modules/aws/budget`, plus a rule requiring at least one notification subscriber.
- `modules/aws/iam-role` — attaches a caller-supplied trust policy plus existing policy ARNs from other modules; authors no policy document itself.
- `examples/aws/basic-site` — a working root config wiring every AWS module above together.
- `policy/aws/testdata/` — `allow`/`deny-*.json` fixture plan JSON for every module rule and for `global.rego`'s S3/DynamoDB/IAM intents.
- `scripts/test-policy-fixtures.sh` — checks each fixture individually against its `allow`/`deny-*` filename convention; `conftest test` on a whole fixture directory at once collapses pass/fail cases into one aggregate result and can hide a regression.
- `scripts/check-manifest.sh` — validates a consuming project's `infra-modules.yml` and that every module `source` ref's `?ref=` matches the declared `module_version`.
- `.github/workflows/ci.yml` — runs the policy fixtures and `terraform fmt`/`validate` across every module and example on every push/PR to `main`.
- `CHANGELOG.md`, this file.
