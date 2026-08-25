# Changelog

All notable changes to this project are documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- `feedback_notification_email` and `existing_topic_arn` on `modules/aws/ses`, which add an `aws_ses_configuration_set` and an SNS `aws_ses_event_destination` (`matching_types = ["bounce", "complaint"]`) so a consumer finds out when a send bounces or triggers a spam complaint — previously the module created only the domain identity, DKIM signing, and the scoped send policy, with no way to observe delivery health at all. Follows `cloudwatch`'s `alert_email`/`existing_topic_arn` shape: a dedicated, KMS-encrypted `aws_sns_topic` is created and subscribed only when `feedback_notification_email` is set and no `existing_topic_arn` is given; passing `existing_topic_arn` reuses a topic instead (e.g. one already shared across alarms). Both default to `null`, so the configuration set, topic, and event destination are skipped entirely and existing consumers are unaffected. New `configuration_set_name` output feeds `SendEmailCommand`'s `ConfigurationSetName` — without passing that on every send, SES never associates the send with the configuration set and no bounce/complaint event fires regardless of what's configured here. New `topic_arn` output mirrors `cloudwatch`'s, for chaining another subscription onto the same topic. Also adds an `aws_sns_topic_policy` granting `ses.amazonaws.com` publish access on a module-created topic, scoped to the account via an `AWS:SourceAccount` condition — SES does not inherit publish permission the way CloudWatch alarm actions do, and omitting this would have events silently dropped with no error at apply or send time. The new configuration set sets `delivery_options { tls_policy = "Require" }`, rejecting a send that can't negotiate TLS to the recipient's MTA rather than falling back to plaintext. Surfaced by a real consumer (`latb-fe`): `lookatthesebirds.com` has production SES access and is sending real mail with no bounce/complaint monitoring, a real AWS account-suspension risk once a domain's rate goes unwatched. `context/features/ses-bounce-complaint-notifications.md`.

## [1.15.0] - 2026-08-23

### Added

- `lambda_edge_origin_request_arn` on `modules/aws/cloudfront-distribution`, attaching a caller-supplied Lambda@Edge function to the `origin-request` event (`include_body = true`) on every lambda-type origin's cache behavior, default and ordered alike. CloudFront's OAC signs a lambda origin's request with SigV4 but never computes the body's payload hash itself — AWS's own docs push that onto whichever caller issues the request, via an `x-amz-content-sha256` header, and Lambda's `AWS_IAM` auth rejects an unsigned payload outright. That's a real option only when the caller is code you author (a hand-written `fetch` can set a header); it has no answer for a caller whose request-issuing runtime you don't control. Attaching the hash computation at `origin-request` instead — which runs before CloudFront's OAC signs the request onward — covers every caller uniformly, with `AWS_IAM`/`signing_behavior = "always"` on the origin left completely untouched. Defaults to `null` (no association), so existing consumers are unaffected. Not attached to s3-type origins' behaviors, which never carry a body upstream. Surfaced by a real consumer (`latb-fe`): every POST with a body 403'd in production (SigV4 mismatch) on both its web and admin CloudFront distributions, and the admin app's Next.js Server Actions have no supported hook for adding a request header, ruling out the client-side-hash workaround for that origin — the docs also name dropping `AWS_IAM` auth entirely as the other alternative, rejected as a real security-posture reduction, not a viable option. `context/fixes/cloudfront-oac-blocks-post-requests.md`.

## [1.14.0] - 2026-08-23

### Added

- `log_group_name` and `log_filter_pattern` on `modules/aws/cloudwatch`, which add the `aws_cloudwatch_log_metric_filter` that produces the metric the alarm watches. The module could only ever alarm on a metric that already existed — alarming on a *log line* meant hand-writing the filter beside the module and keeping its `metric_transformation` name/namespace in sync with the alarm's inputs by hand, with nothing checking they matched. The filter now publishes under the module's own `namespace`/`metric_name` (deliberately reused rather than given separate inputs, since an alarm watching a different metric than the filter publishes silently never fires), with `value = "1"` and `default_value = "0"` so the alarm reports 0 for a quiet period instead of sitting in `INSUFFICIENT_DATA` until its first hit. Both default to `null`, so existing consumers are unaffected. The two must be set together, enforced by a precondition on `aws_cloudwatch_metric_alarm.primary` rather than on the filter — the filter is `count = 0` in exactly the misconfiguration being caught, and keying its count on `log_group_name` alone instead plans a filter with a null `pattern`, which the provider rejects first with a bare "Missing required argument" (caught by the new test, not assumed). A precondition rather than a variable `validation` block for the same reason as `1.12.0`'s `qualifier`: cross-variable validation needs Terraform >= 1.9 and this module floors at 1.7.
- `existing_topic_arn` on `modules/aws/cloudwatch`, letting an alarm notify a topic that already exists (typically another instance's `topic_arn` output) instead of always creating its own. `aws_sns_topic.alerts` becomes conditional and every notifying resource — the alarm's `alarm_actions`/`ok_actions`, the optional email subscription, and the `topic_arn` output — reads a new `local.topic_arn` that resolves to either. Defaults to `null` (create a dedicated topic), so existing consumers are unaffected, and `topic_arn` keeps working for consumers that chain it elsewhere. `policy/aws/modules/cloudwatch.rego` needs no change: it denies unencrypted planned `aws_sns_topic` resources, and this plans none when reusing. Surfaced by a real consumer (`latb-fe`): its subscriber-confirmation-email alarm had been written as a hand-rolled `aws_cloudwatch_log_metric_filter` plus a module alarm minting a second SNS topic, because the module could do neither half — and a check of the live account found all three of that project's existing alarm topics (`web-lambda-errors`, `admin-lambda-errors`, `posts-table-throttles`) sitting at **zero subscriptions**, so every alarm it had was firing into a topic nobody received. Sharing one topic across alarms means one subscription confirmation to keep alive rather than one per alarm. Because giving `aws_sns_topic.alerts` a `count` also changes its address to `aws_sns_topic.alerts[0]`, the module ships a `moved` block for it — without one, every existing consumer's upgrade would plan a destroy-and-recreate of a live alert topic and silently drop its subscriptions, each of which needs a fresh confirmation click to restore. Upgrading is a no-op state move.

## [1.13.0] - 2026-08-22

### Added

- `qualifier` on `modules/aws/cloudfront-distribution`'s per-origin `origins` entries (lambda origins only), threaded through both `aws_lambda_permission` resources (`InvokeFunctionUrl` and `InvokeFunction`). The module previously granted CloudFront invoke access only on a Lambda origin's unqualified ARN — no way to scope the grant to an alias or version. When a Lambda origin's Function URL targets an alias (via `lambda-function-url`'s own `qualifier`, added in `1.12.0`), CloudFront's origin invokes the alias-qualified ARN, but the unqualified grant doesn't cover it, so AWS_IAM authorization rejects every request with a 403 `AccessDeniedException` straight from the Function URL. `null` (the default) preserves an unqualified grant exactly as before, so existing consumers are unaffected. A new `origins` validation rejects `qualifier` set on a non-`lambda` origin. Surfaced by a real consumer (`latb-fe`): the `1.12.0` apply that put `web_lambda`/`admin_lambda` behind a `live` alias broke production on all three public hostnames within minutes — `aws lambda get-policy --qualifier live` returned `ResourceNotFoundException`, confirming no permission existed for that qualifier at all, while the unqualified policy (`$LATEST` only) was present and unchanged. That incident was patched with standalone, hand-written `aws_lambda_permission` resources in the consumer's own Terraform as a same-day stopgap; this closes the gap in the module itself so a future qualifier-based Lambda origin needs no consumer-side workaround.

## [1.12.0] - 2026-08-22

### Added

- `publish`, `alias_name`, and `qualifier` on `modules/aws/lambda-function-url`, plus `published_version`/`alias_arn` outputs. The module previously had no way to get a versioned deploy or a stable alias for rollback — every apply only ever updated `$LATEST`, and the Function URL always targeted it with no qualifier input. `publish` (default `false`) opts a function into cutting an immutable version on every apply; `alias_name` (default `"live"`) names the alias created to track it; `qualifier`, only settable when `publish` is `true` (enforced via a resource precondition rather than a variable `validation` block, since cross-variable validation needs Terraform >= 1.9 and this module floors at 1.7), points the Function URL at that alias instead of `$LATEST`. All three default to values that preserve existing behavior, so existing consumers are unaffected. Surfaced by a real consumer (`latb-fe`): `project-overview.md`'s Rollback section had described alias-based rollback as if it were built, and it never was — `list-aliases` returned `[]` and `list-versions-by-function` returned only `$LATEST` against the real deployed functions. Rollback today means reverting a commit and re-running the whole CI/CD pipeline (minutes, always rebuilds); with this, it becomes repointing an alias (seconds, no rebuild).

## [1.11.0] - 2026-08-22

### Added

- New module `modules/aws/cloudtrail-trail`: a CloudTrail trail plus the S3 bucket it logs to, composed on top of this repo's own `s3-bucket` module and wired with a bucket policy scoped to that specific trail's ARN (`SourceArn` condition on every statement). Log file validation is always on, with no opt-out. Defaults to a multi-region trail covering global service events, with management-events-only logging (data events are billed per event and are opt-in via `event_selector`). Surfaced by a real consumer (`latb-fe`): the account had **no CloudTrail trail at all** (`describe-trails` returned `[]`), discovered mid-way through that project's CI role IAM tightening, where a throwaway trail was stood up for IAM Access Analyzer's policy generation and torn down again afterward rather than left as untracked infra. New `policy/aws/modules/cloudtrail-trail.rego` denies a plan where a trail's `enable_log_file_validation` isn't `true`, and a new "Account activity must be auditable" row was added to `project-overview.md`'s Security baseline intents table.

## [1.10.0] - 2026-08-22

### Changed

- `policy/aws/global.rego`'s "no wildcard (\*) IAM permissions" resource rule now exempts a statement whose actions are *all* drawn from a small closed allowlist of AWS APIs that have no resource-level permission support: `cognito-idp:DescribeUserPoolDomain`, `kms:ListAliases`, `ses:GetIdentityDkimAttributes`, `ses:GetIdentityVerificationAttributes`. IAM evaluates these against `*` regardless of what ARN a policy names, so scoping them restricts nothing — it only makes the grant silently fail. Surfaced by a real consumer (`latb-fe`'s CI role): `terraform plan` could not refresh its live `aws_cognito_user_pool_domain`, `aws_ses_domain_identity`, or `aws_ses_domain_dkim` resources, each failing with `AccessDeniedException ... on resource: *` despite an ARN-scoped grant of the same action, leaving the project's own mandatory policy gate and AWS's authorization model in direct conflict with no compliant way to pass both. The wildcard **action** rule is untouched, and the exemption applies only when every action in the statement is allowlisted — a statement mixing an allowlisted action with a resource-scopable one (e.g. `kms:ListAliases` + `s3:GetObject`) is still denied, so this cannot be used to smuggle a scopable action onto a wildcard resource. Adding an entry remains a policy decision: confirm the action genuinely has no resource-level support (an ARN-scoped grant fails naming `on resource: *`) rather than assuming it. Verified against both conftest 0.69.0 (this repo's CI) and 0.53.0 (the version the consumer's gate pins), with new `testdata/iam-wildcard-exemption/` fixtures covering the exemption, the mixed-statement denial, and an unlisted action; the pre-existing `testdata/ses/deny-wildcard-resource.json` still fires unchanged.

## [1.9.0] - 2026-08-20

### Added

- Per-origin `cache_policy_id`/`origin_request_policy_id`/`response_headers_policy_id` on `modules/aws/cloudfront-distribution`'s `origins` entries. The module-level vars of the same name previously applied to every cache behavior — default and ordered alike — with no way to give one `path_pattern` a different cache policy than the rest of the distribution while still targeting the same underlying origin (e.g. a Lambda origin whose default behavior must stay `CachingDisabled` for RSC/dynamic responses, but whose `/_next/static/*` path is safe and worth caching). An origin can now repeat another origin's `domain_name`/`function_name` under a distinct `origin_id` (each still gets its own `aws_lambda_permission` grant, keyed by `origin_id`) and set its own `cache_policy_id` etc., which wins over the module-level default for that origin's `ordered_cache_behavior` only. All three default to `null` (falls back to the module-level var), so existing consumers are unaffected. Surfaced by a real consumer (`latb-fe`'s `web_distribution`) needing `/_next/static/*` cached with `Managed-CachingOptimized` while the default behavior stayed on `Managed-CachingDisabled` — the module had no way to express "same origin, second path, different cache policy" before this.

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
