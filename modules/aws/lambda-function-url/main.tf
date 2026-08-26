# AC-3: trust policy scoped to the Lambda service only — nothing else can assume this role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "primary" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# AC-6: least-privilege baseline — CloudWatch Logs only, via AWS's own managed
# policy rather than a hand-rolled inline policy, so the permission set can't
# drift into a wildcard resource/action.
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.primary.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# AC-6: attaches existing, already-scoped policies (e.g. the
# read_policy_arn/send_policy_arn output of another module in this repo) —
# this module never authors a policy document itself, so it can't introduce
# a wildcard action/resource here.
#
# Keyed by index rather than toset(var.additional_policy_arns): the list's
# length is always known at plan time, even when an entry is itself a
# not-yet-applied module's output (e.g. a brand-new secrets-manager module's
# read_policy_arn). toset() needs every value to determine set membership,
# so a single unknown entry makes the whole for_each unresolvable ("Invalid
# for_each argument") until that entry's module is applied first.
resource "aws_iam_role_policy_attachment" "additional" {
  for_each   = { for idx, arn in var.additional_policy_arns : tostring(idx) => arn }
  role       = aws_iam_role.primary.name
  policy_arn = each.value
}

resource "aws_lambda_function" "primary" {
  function_name    = var.function_name
  role             = aws_iam_role.primary.arn
  handler          = var.handler
  runtime          = var.runtime
  filename         = var.filename
  source_code_hash = var.source_code_hash
  timeout          = var.timeout
  memory_size      = var.memory_size
  layers           = var.layers
  publish          = var.publish
  tags             = var.tags

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }
}

# Only created when publish is true — with publish false there's no version
# beyond $LATEST for an alias to point at.
resource "aws_lambda_alias" "primary" {
  count = var.publish ? 1 : 0

  name             = var.alias_name
  function_name    = aws_lambda_function.primary.function_name
  function_version = aws_lambda_function.primary.version
}

# AC-3: Compute endpoints must not be anonymously invokable. AWS_IAM is
# hardcoded — there is no variable to opt into NONE/public. Front this with
# CloudFront Origin Access Control if the function needs to be internet-reachable.
resource "aws_lambda_function_url" "primary" {
  function_name      = aws_lambda_function.primary.function_name
  qualifier          = var.qualifier
  authorization_type = "AWS_IAM"
  invoke_mode        = var.invoke_mode

  lifecycle {
    precondition {
      condition     = var.qualifier == null || var.publish
      error_message = "qualifier can only be set when publish is true — there is no alias or version to target otherwise ($LATEST is the only qualifier available, and that's already the default)."
    }
  }
}
