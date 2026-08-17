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
resource "aws_iam_role_policy_attachment" "additional" {
  for_each   = toset(var.additional_policy_arns)
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
  tags             = var.tags

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }
}

# AC-3: Compute endpoints must not be anonymously invokable. AWS_IAM is
# hardcoded — there is no variable to opt into NONE/public. Front this with
# CloudFront Origin Access Control if the function needs to be internet-reachable.
resource "aws_lambda_function_url" "primary" {
  function_name      = aws_lambda_function.primary.function_name
  authorization_type = "AWS_IAM"
}
