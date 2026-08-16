output "domain_identity_arn" { value = aws_ses_domain_identity.primary.arn }
output "verification_token" { value = aws_ses_domain_identity.primary.verification_token }
output "dkim_tokens" { value = aws_ses_domain_dkim.primary.dkim_tokens }
output "send_policy_arn" { value = aws_iam_policy.send.arn }
