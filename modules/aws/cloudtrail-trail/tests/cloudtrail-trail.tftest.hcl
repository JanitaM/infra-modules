# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  trail_name  = "test-account-trail"
  bucket_name = "test-audit-logs-123456789012"
}

run "log_file_validation_always_on" {
  command = plan

  assert {
    condition     = aws_cloudtrail.primary.enable_log_file_validation == true
    error_message = "enable_log_file_validation must always be true, regardless of input"
  }
}

run "defaults_to_multi_region_and_global_events" {
  command = plan

  assert {
    condition     = aws_cloudtrail.primary.is_multi_region_trail == true
    error_message = "is_multi_region_trail should default to true"
  }

  assert {
    condition     = aws_cloudtrail.primary.include_global_service_events == true
    error_message = "include_global_service_events should default to true"
  }
}

run "single_region_when_set_false" {
  command = plan

  variables {
    is_multi_region_trail = false
  }

  assert {
    condition     = aws_cloudtrail.primary.is_multi_region_trail == false
    error_message = "is_multi_region_trail should be overridable to false"
  }
}

run "kms_key_id_omitted_when_unset" {
  command = plan

  assert {
    condition     = aws_cloudtrail.primary.kms_key_id == null
    error_message = "kms_key_id should be null when not set, relying on the bucket's SSE-S3"
  }
}

run "kms_key_id_included_when_set" {
  command = plan

  variables {
    kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/test-key"
  }

  assert {
    condition     = aws_cloudtrail.primary.kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/test-key"
    error_message = "kms_key_id should be passed through when set"
  }
}

run "event_selector_defaults_to_management_events_only" {
  command = plan

  assert {
    condition     = tolist(aws_cloudtrail.primary.event_selector)[0].read_write_type == "All"
    error_message = "default event_selector should cover all read/write types"
  }

  assert {
    condition     = tolist(aws_cloudtrail.primary.event_selector)[0].include_management_events == true
    error_message = "default event_selector should include management events"
  }

  assert {
    condition     = length(tolist(aws_cloudtrail.primary.event_selector)[0].data_resource) == 0
    error_message = "default event_selector should have no data_resource blocks (management events only)"
  }
}

run "event_selector_accepts_data_events_when_set" {
  command = plan

  variables {
    event_selector = [{
      read_write_type           = "All"
      include_management_events = true
      data_resources = [{
        type   = "AWS::S3::Object"
        values = ["arn:aws:s3:::example-bucket/"]
      }]
    }]
  }

  assert {
    condition     = length(tolist(aws_cloudtrail.primary.event_selector)[0].data_resource) == 1
    error_message = "event_selector should accept explicit data_resources when the caller opts in"
  }
}

run "bucket_policy_scoped_to_this_trail_arn" {
  command = apply

  assert {
    condition     = strcontains(aws_s3_bucket_policy.log_bucket.policy, "arn:aws:cloudtrail:")
    error_message = "bucket policy should condition on this trail's own ARN (SourceArn), not a wildcard"
  }

  assert {
    condition     = strcontains(aws_s3_bucket_policy.log_bucket.policy, var.trail_name)
    error_message = "the computed trail ARN embedded in the bucket policy should include trail_name"
  }
}
