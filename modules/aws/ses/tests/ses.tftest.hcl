# CI has no AWS credentials, so every run block here executes against a
# mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  domain = "mail.example.com"
}

run "no_feedback_resources_by_default" {
  command = plan

  # data.aws_iam_policy_document.send's resources assertion below needs the
  # identity ARN known at plan time — mock_provider otherwise leaves it
  # "(not yet known)", which the set it's read into can't evaluate length()
  # on.
  override_resource {
    target          = aws_ses_domain_identity.primary
    override_during = plan
    values = {
      arn = "arn:aws:ses:us-east-1:123456789012:identity/mail.example.com"
    }
  }

  assert {
    condition     = length(aws_ses_configuration_set.feedback) == 0
    error_message = "no aws_ses_configuration_set should be created when neither feedback input is set"
  }

  assert {
    condition     = length(aws_sns_topic.feedback) == 0
    error_message = "no aws_sns_topic should be created when neither feedback input is set"
  }

  assert {
    condition     = length(aws_ses_event_destination.feedback) == 0
    error_message = "no aws_ses_event_destination should be created when neither feedback input is set"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.send.statement[0].resources) == 1
    error_message = "the send policy should only reference the domain identity ARN when no configuration set exists"
  }
}

run "feedback_notification_email_creates_full_chain" {
  command = plan

  variables {
    feedback_notification_email = "ops@example.com"
  }

  # Same reason as "no_feedback_resources_by_default"'s override: the send
  # policy's resources assertion needs both ARNs known at plan time.
  override_resource {
    target          = aws_ses_domain_identity.primary
    override_during = plan
    values = {
      arn = "arn:aws:ses:us-east-1:123456789012:identity/mail.example.com"
    }
  }

  override_resource {
    target          = aws_ses_configuration_set.feedback[0]
    override_during = plan
    values = {
      arn = "arn:aws:ses:us-east-1:123456789012:configuration-set/mail-example-com-feedback"
    }
  }

  # aws_kms_key.feedback's policy argument validates it's real JSON even at
  # plan time — data.aws_iam_policy_document's json output comes back invalid
  # under mock_provider unless overridden explicitly (feedback_topic_publish's
  # json feeds aws_sns_topic_policy instead, which doesn't validate
  # client-side, so it doesn't need this).
  override_data {
    target = data.aws_iam_policy_document.feedback_kms[0]
    values = {
      json = "{}"
    }
  }

  # aws_sns_topic.feedback's kms_master_key_id reads aws_kms_key.feedback's
  # key_id, otherwise unknown until apply — a fixed key_id here is what makes
  # the equality assertion below evaluable at plan time.
  override_resource {
    target          = aws_kms_key.feedback[0]
    override_during = plan
    values = {
      key_id = "12345678-1234-1234-1234-123456789012"
    }
  }

  assert {
    condition     = length(aws_kms_key.feedback) == 1
    error_message = "a customer-managed KMS key should be created when kms_key_id is unset"
  }

  assert {
    condition     = aws_sns_topic.feedback[0].kms_master_key_id == aws_kms_key.feedback[0].key_id
    error_message = "the topic should be encrypted with the module-created key"
  }

  assert {
    condition     = length(aws_ses_configuration_set.feedback) == 1
    error_message = "an aws_ses_configuration_set should be created when feedback_notification_email is set"
  }

  assert {
    condition     = length(aws_sns_topic.feedback) == 1
    error_message = "a dedicated aws_sns_topic should be created when feedback_notification_email is set without existing_topic_arn"
  }

  assert {
    condition     = length(aws_sns_topic_subscription.feedback_email) == 1
    error_message = "an email subscription should be created when feedback_notification_email is set"
  }

  assert {
    condition     = aws_sns_topic_subscription.feedback_email[0].endpoint == "ops@example.com"
    error_message = "the subscription endpoint should be feedback_notification_email"
  }

  assert {
    condition     = length(aws_ses_event_destination.feedback) == 1
    error_message = "an aws_ses_event_destination should be created when feedback_notification_email is set"
  }

  assert {
    condition     = toset(aws_ses_event_destination.feedback[0].matching_types) == toset(["bounce", "complaint"])
    error_message = "the event destination should match bounce and complaint events"
  }

  assert {
    condition     = length(aws_sns_topic_policy.feedback) == 1
    error_message = "a topic policy granting ses.amazonaws.com publish access should be created alongside a module-created topic"
  }

  assert {
    condition     = length(data.aws_iam_policy_document.send.statement[0].resources) == 2
    error_message = "the send policy should include the configuration set's ARN once one is created, or SendEmailCommand's ConfigurationSetName gets AccessDenied at send time"
  }
}

run "existing_topic_arn_skips_own_topic" {
  command = plan

  variables {
    existing_topic_arn = "arn:aws:sns:us-east-1:123456789012:shared-feedback"
  }

  assert {
    condition     = length(aws_sns_topic.feedback) == 0
    error_message = "no aws_sns_topic should be created when existing_topic_arn is set"
  }

  assert {
    condition     = length(aws_sns_topic_policy.feedback) == 0
    error_message = "no topic policy should be created for a topic this module does not own"
  }

  assert {
    condition     = length(aws_ses_configuration_set.feedback) == 1
    error_message = "an aws_ses_configuration_set should still be created when existing_topic_arn is set"
  }

  assert {
    condition     = aws_ses_event_destination.feedback[0].sns_destination[0].topic_arn == "arn:aws:sns:us-east-1:123456789012:shared-feedback"
    error_message = "the event destination should point at the existing topic"
  }

  assert {
    condition     = length(aws_sns_topic_subscription.feedback_email) == 0
    error_message = "no email subscription should be created when feedback_notification_email is not set"
  }

  assert {
    condition     = length(aws_kms_key.feedback) == 0
    error_message = "no KMS key should be created when existing_topic_arn is set (no topic to encrypt)"
  }
}

run "caller_supplied_kms_key_id_skips_module_key" {
  command = plan

  variables {
    feedback_notification_email = "ops@example.com"
    kms_key_id                  = "arn:aws:kms:us-east-1:123456789012:key/caller-owned-key"
  }

  assert {
    condition     = length(aws_kms_key.feedback) == 0
    error_message = "no KMS key should be created when the caller supplies kms_key_id"
  }

  assert {
    condition     = aws_sns_topic.feedback[0].kms_master_key_id == "arn:aws:kms:us-east-1:123456789012:key/caller-owned-key"
    error_message = "the topic should be encrypted with the caller-supplied key"
  }
}
