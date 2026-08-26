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

# Keyed by index rather than toset(var.policy_arns): the list's length is
# always known at plan time, even when an entry is itself a not-yet-applied
# module's output. toset() needs every value to determine set membership, so
# a single unknown entry makes the whole for_each unresolvable ("Invalid
# for_each argument") until that entry's module is applied first.
resource "aws_iam_role_policy_attachment" "this" {
  for_each   = { for idx, arn in var.policy_arns : tostring(idx) => arn }
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
