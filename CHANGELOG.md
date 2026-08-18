# Changelog

All notable changes to this project are documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

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
