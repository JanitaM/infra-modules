# webhook-handler

A single Lambda Function URL, standing alone — no CloudFront, no other modules wired in. Shows the minimum needed to get an HTTPS endpoint backed by a Lambda function, secured the way this module always secures one.

## What this builds

`modules/aws/lambda-function-url` deploying `src/index.js` (a no-op handler — replace it with real logic). The function URL is `AWS_IAM`-authenticated, never public — that's hardcoded in the module, not a setting here. To make this reachable from the internet, front it with `modules/aws/cloudfront-distribution` using Origin Access Control (see `../basic-site` for a worked example of that combination, including the WAF web ACL a public edge requires).

## Prerequisites

- Terraform >= 1.6
- The `archive` provider (`hashicorp/archive`, declared in `main.tf`'s `terraform` block) — zips `src/index.js` into `build/handler.zip` at plan time, no separate build step
- AWS credentials for the account you want to deploy into

## Using this as a starting point

Replace `src/index.js` with your handler, and `function_name` with something specific to your project. Everything else (`runtime`, `timeout`, `memory_size`, `environment_variables`) is a module variable — see `modules/aws/lambda-function-url/variables.tf`.

## State management

This example has no backend configured, so `terraform init` defaults to local state. Fine for trying it out; not for real use — see the root [README](../../../README.md#state-management) for the bootstrap steps before using this as a real starting point.

## Running it

```
terraform init
terraform plan
```

This repo's own CI only runs `terraform validate` against this example (no real AWS credentials in CI) — `plan`/`apply` require your own credentials and are on you to run.
