package main

import rego.v1

# lambda-function-url module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# compute endpoints must not be anonymously invokable — is specific to Lambda
# Function URLs, so it lives here rather than in global.rego alongside the
# cross-resource intents (encryption, public storage) that recur across
# multiple resource types.

# ---- Intent: compute endpoints must not be anonymously invokable ----

deny contains msg if {
  fn_url := input.resource_changes[_]
  fn_url.type == "aws_lambda_function_url"
  fn_url.change.after.authorization_type != "AWS_IAM"

  msg := sprintf(
    "Lambda Function URL '%s' does not use AWS_IAM authorization (found '%v'). Function URLs must never be anonymously invokable — front with CloudFront Origin Access Control if public access is needed.",
    [fn_url.address, fn_url.change.after.authorization_type],
  )
}
