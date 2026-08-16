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

## Outputs

| Name | Description |
|---|---|
| `function_arn` | Function ARN |
| `function_name` | Function name |
| `function_url` | Invoke URL for the Function URL |
| `role_arn` | Execution role ARN |

## What this module always does, with no opt-out

- Requires `AWS_IAM` authorization on the Function URL — never `NONE`/public
- Creates a dedicated execution role trusted only by the Lambda service
- Grants that role CloudWatch Logs permissions only, via AWS's managed `AWSLambdaBasicExecutionRole` policy
