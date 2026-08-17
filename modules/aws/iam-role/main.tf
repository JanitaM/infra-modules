# AC-6: this module never authors a policy document itself, so it cannot
# introduce a wildcard action/resource of its own — it only attaches
# already-scoped policies (e.g. the read_policy_arn/send_policy_arn outputs
# of other modules here) to a role whose trust policy the caller supplies.
# See policy/aws/global.rego for the plan-time check that still applies to
# any aws_iam_policy/aws_iam_role_policy those attached ARNs point at.
resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.description
  assume_role_policy   = var.assume_role_policy
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each   = toset(var.policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
