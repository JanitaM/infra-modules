variable "domain" {
  type        = string
  description = "Domain to verify as an SES identity, e.g. mail.example.com. DNS records for verification and DKIM must be added separately (see outputs)."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the sending IAM policy, and to the bounce/complaint SNS topic when this module creates one."
  default     = {}
}

variable "feedback_notification_email" {
  type        = string
  description = "Email address subscribed to bounce/complaint notifications. Leave null to skip creating the configuration set, topic, and event destination entirely (no bounce/complaint monitoring)."
  default     = null
}

variable "existing_topic_arn" {
  type        = string
  description = "Bounce/complaint topic to notify instead of creating one, e.g. the topic_arn output of another instance of this module or of the cloudwatch module. Leave null to create a dedicated topic when feedback_notification_email is set."
  default     = null
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID or ARN to encrypt the bounce/complaint SNS topic with. Defaults to the AWS-managed alias/aws/sns key when null. Ignored when existing_topic_arn is set, since no topic is created."
  default     = null
}
