# CI has no AWS credentials, so every run block here executes against a
# mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  domain = "mail.example.com"
}

run "no_feedback_resources_by_default" {
  command = plan

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
}

run "feedback_notification_email_creates_full_chain" {
  command = plan

  variables {
    feedback_notification_email = "ops@example.com"
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
}
