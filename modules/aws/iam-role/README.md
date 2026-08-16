# iam-role

An IAM role with a caller-supplied trust policy, plus a list of existing policy ARNs to attach.

This module never authors a policy document of its own — it only attaches ARNs the caller passes in, typically the scoped `read_policy_arn`/`send_policy_arn` output of another module in this repo (`ssm`, `secrets-manager`, `ses`, ...). Since it creates no `aws_iam_policy` or `aws_iam_role_policy` resource, it cannot itself introduce a wildcard action or resource — `policy/aws/global.rego`'s "no wildcard IAM" rule still applies to whatever the attached ARNs point at, just not to anything this module creates directly.

There is no input for an inline policy document. A role that needs a policy beyond what's already published by another module should get that policy from a module that owns the resource being granted access to, not from a generic escape hatch here.

## Usage

```hcl
module "app_role" {
  source = "github.com/JanitaM/infra-modules//modules/aws/iam-role?ref=v1.0.0"

  role_name = "example-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  policy_arns = [
    module.api_key.read_policy_arn,
    module.mail_domain.send_policy_arn,
  ]

  tags = {
    project = "example"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `role_name` | IAM role name | `string` | — (required) |
| `description` | Role description | `string` | `""` |
| `assume_role_policy` | Trust policy JSON naming which principal can assume this role | `string` | — (required) |
| `policy_arns` | ARNs of existing policies to attach | `list(string)` | `[]` |
| `max_session_duration` | Maximum session duration in seconds | `number` | `3600` |
| `tags` | Tags applied to the role | `map(string)` | `{}` |

## Outputs

| Name | Description |
|---|---|
| `role_name` | Role name |
| `role_arn` | Role ARN |
| `role_id` | Role's unique ID |

## What this module always does, with no opt-out

- Requires an explicit trust policy — there is no default `assume_role_policy`, so every role states who can assume it
- Attaches only pre-existing policy ARNs; never authors a policy document, so it cannot be the source of a wildcard action/resource itself
