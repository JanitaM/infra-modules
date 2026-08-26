# Regression fixture for the toset()-on-unknown-values "Invalid for_each
# argument" failure: terraform_data.id is a computed attribute, unknown at
# plan time and known only after apply — the same shape as a brand-new
# module's policy-ARN output (e.g. secrets-manager's read_policy_arn) before
# its first apply. Wrapping the module under test here, rather than passing
# this in from the test file directly, is necessary because a
# not-yet-applied value can only be produced by a real resource in the same
# plan, and test files can't declare resources of their own.
resource "terraform_data" "unapplied_policy" {}

module "under_test" {
  source = "../../.."

  function_name = "test-function"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  filename      = "function.zip"

  additional_policy_arns = [
    "arn:aws:iam::123456789012:policy/${terraform_data.unapplied_policy.id}",
    "arn:aws:iam::123456789012:policy/known-policy",
  ]
}
