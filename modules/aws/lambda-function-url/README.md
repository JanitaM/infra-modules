# lambda-function-url

A Lambda function with a Function URL that always requires AWS_IAM authorization — it is never anonymously invokable.

This module has no input for making the function URL public. Endpoints that need to be reachable from the internet stay IAM-authorized and get access through CloudFront Origin Access Control instead — see the `cloudfront-distribution` module.

## Usage

```hcl
module "webhook_handler" {
  source        = "github.com/JanitaM/infra-modules//modules/aws/lambda-function-url?ref=v1.0.0"
  function_name = "example-webhook-handler"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/build/handler.zip"
  tags = {
    project = "example"
  }
}
```

## Versioned deploys and alias-based rollback

By default (`publish = false`) the function only ever has `$LATEST` — every apply overwrites
it in place, and the Function URL always serves whatever was deployed last. Set `publish =
true` to get an immutable version on every apply, plus an alias (`alias_name`, default
`"live"`) that tracks the newest one. Point the Function URL at that alias with `qualifier =
var.alias_name` (or a literal matching string) so it follows the alias rather than always
tracking `$LATEST` — that's what makes repointing the alias, without a `terraform apply`,
actually change what's served:

```hcl
module "web" {
  source        = "github.com/JanitaM/infra-modules//modules/aws/lambda-function-url?ref=v1.12.0"
  function_name = "example-web"
  handler       = "run.sh"
  runtime       = "nodejs20.x"
  filename      = "${path.module}/build/web-lambda.zip"
  publish       = true
  alias_name    = "live"
  qualifier     = "live"
}
```

Rollback is then an out-of-band `aws lambda update-alias --function-name example-web --name
live --function-version <N>` (or re-running `terraform apply` pinned at an older zip/hash) —
no rebuild required either way, since the target version's code already exists. This module
does not manage rollback itself; it only makes the version + alias exist so a consumer can.

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `function_name` | Lambda function name | `string` | — (required) |
| `handler` | Function entrypoint, e.g. `index.handler` | `string` | — (required) |
| `runtime` | Lambda runtime identifier (`nodejs20.x`, `nodejs18.x`, `python3.12`, `python3.11`) | `string` | — (required) |
| `filename` | Path to the deployment package (`.zip`) | `string` | — (required) |
| `source_code_hash` | Base64 SHA256 of the deployment package, for change detection | `string` | `null` |
| `timeout` | Function timeout, in seconds | `number` | `3` |
| `memory_size` | Function memory, in MB | `number` | `128` |
| `environment_variables` | Environment variables passed to the function | `map(string)` | `{}` |
| `tags` | Tags applied to the function and its execution role | `map(string)` | `{}` |
| `additional_policy_arns` | ARNs of existing policies to attach to the execution role, beyond the CloudWatch Logs baseline | `list(string)` | `[]` |
| `layers` | ARNs of Lambda layers to attach (e.g. a published extension layer). Max 5, matching Lambda's own limit | `list(string)` | `[]` |
| `invoke_mode` | Function URL invoke mode: `BUFFERED` or `RESPONSE_STREAM`. Required alongside a streaming-capable adapter (e.g. the Lambda Web Adapter's own streaming env var) for a proxied app to actually stream its response — the adapter's env var alone does not change this | `string` | `"BUFFERED"` |
| `publish` | Publish a new immutable version on every apply that changes the function | `bool` | `false` |
| `alias_name` | Name of the alias tracking the published version. Only created when `publish` is `true` | `string` | `"live"` |
| `qualifier` | Alias name or version number the Function URL invokes. `null` invokes `$LATEST`. Can only be set when `publish` is `true` | `string` | `null` |

## Outputs

| Name | Description |
|---|---|
| `function_arn` | Function ARN |
| `function_name` | Function name |
| `function_url` | Invoke URL for the Function URL |
| `role_arn` | Execution role ARN |
| `published_version` | The version published by this apply. `"$LATEST"` when `publish` is `false` |
| `alias_arn` | ARN of the alias tracking `published_version`. `null` when `publish` is `false` |

## What this module always does, with no opt-out

- Requires `AWS_IAM` authorization on the Function URL — never `NONE`/public
- Creates a dedicated execution role trusted only by the Lambda service
- Grants that role CloudWatch Logs permissions only, via AWS's managed `AWSLambdaBasicExecutionRole` policy
