# sessions-table

The smallest possible example: one `dynamodb-table` module call, no other pieces. Start here if you just want to see what calling a single module from this repo looks like before working through a bigger example.

## What this builds

A DynamoDB table (`example-sessions`) with `session_id` as its hash key. Point-in-time recovery and encryption at rest are on by default — the module hardcodes both, no variable to turn them off.

## Prerequisites

- Terraform >= 1.6
- AWS credentials for the account you want to deploy into
- Nothing else — no source code to package, no other modules to wire in

## Using this as a starting point

Everything hardcoded here (`table_name`, `hash_key`, the `project` tag) is a placeholder — replace it with your own values. If you need a sort key, pass `range_key`; see `modules/aws/dynamodb-table/variables.tf` for every option.

## State management

This example has no backend configured, so `terraform init` defaults to local state. Fine for trying it out; not for real use — see the root [README](../../../README.md#state-management) for the bootstrap steps before using this as a real starting point.

## Running it

```
terraform init
terraform plan
```

This repo's own CI only runs `terraform validate` against this example (no real AWS credentials in CI) — `plan`/`apply` require your own credentials and are on you to run.
