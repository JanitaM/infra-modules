output "domain_identity_arn" { value = aws_ses_domain_identity.primary.arn }
output "verification_token" { value = aws_ses_domain_identity.primary.verification_token }
output "dkim_tokens" { value = aws_ses_domain_dkim.primary.dkim_tokens }
output "send_policy_arn" { value = aws_iam_policy.send.arn }

# null when neither feedback_notification_email nor existing_topic_arn is set.
output "configuration_set_name" { value = one(aws_ses_configuration_set.feedback[*].name) }

# The topic bounce/complaint events are published to, whether this module
# created it or a caller passed one in via existing_topic_arn. null when
# neither feedback input is set.
output "topic_arn" { value = local.topic_arn }
