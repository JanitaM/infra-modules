# CI has no AWS credentials (see README, "Testing module logic"), so every
# run block here executes against a mocked provider, never real AWS.
mock_provider "aws" {}

variables {
  bucket_name = "test-bucket"
}

run "no_cors_configuration_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.primary) == 0
    error_message = "no aws_s3_bucket_cors_configuration should be planned when cors_rules is empty"
  }
}

run "cors_rule_creates_cors_configuration" {
  command = plan

  variables {
    cors_rules = [{
      allowed_origins = ["https://app.example.com"]
      allowed_methods = ["GET", "PUT"]
      allowed_headers = ["*"]
      expose_headers  = ["ETag"]
    }]
  }

  assert {
    condition     = length(aws_s3_bucket_cors_configuration.primary) == 1
    error_message = "one aws_s3_bucket_cors_configuration should be planned when cors_rules is non-empty"
  }

  assert {
    condition     = length(tolist(aws_s3_bucket_cors_configuration.primary[0].cors_rule)) == 1
    error_message = "one cors_rule block should be planned per cors_rules list entry"
  }

  assert {
    condition     = contains(tolist(aws_s3_bucket_cors_configuration.primary[0].cors_rule)[0].allowed_origins, "https://app.example.com")
    error_message = "cors_rule's allowed_origins should match the input variable"
  }
}

run "multiple_cors_rules_create_multiple_blocks" {
  command = plan

  variables {
    cors_rules = [
      {
        allowed_origins = ["https://app.example.com"]
        allowed_methods = ["GET", "PUT"]
        allowed_headers = ["*"]
      },
      {
        allowed_origins = ["https://other.example.com"]
        allowed_methods = ["GET"]
        allowed_headers = ["*"]
      },
    ]
  }

  assert {
    condition     = length(tolist(aws_s3_bucket_cors_configuration.primary[0].cors_rule)) == 2
    error_message = "one cors_rule block should be planned per cors_rules list entry"
  }
}

run "aes256_sse_by_default" {
  command = plan

  assert {
    condition     = tolist(aws_s3_bucket_server_side_encryption_configuration.primary.rule)[0].apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "sse_algorithm should default to AES256 when kms_key_arn is not set"
  }

  assert {
    condition     = tolist(aws_s3_bucket_server_side_encryption_configuration.primary.rule)[0].apply_server_side_encryption_by_default[0].kms_master_key_id == null
    error_message = "kms_master_key_id should be null when kms_key_arn is not set"
  }
}

run "kms_sse_when_key_arn_set" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/test-key"
  }

  assert {
    condition     = tolist(aws_s3_bucket_server_side_encryption_configuration.primary.rule)[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "sse_algorithm should switch to aws:kms when kms_key_arn is set"
  }

  assert {
    condition     = tolist(aws_s3_bucket_server_side_encryption_configuration.primary.rule)[0].apply_server_side_encryption_by_default[0].kms_master_key_id == "arn:aws:kms:us-east-1:123456789012:key/test-key"
    error_message = "kms_master_key_id should match var.kms_key_arn"
  }
}

run "object_lock_disabled_by_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket.primary.object_lock_enabled == false
    error_message = "object_lock_enabled should default to false"
  }
}

run "object_lock_enabled_with_versioning" {
  command = plan

  variables {
    object_lock_enabled = true
  }

  assert {
    condition     = aws_s3_bucket.primary.object_lock_enabled == true
    error_message = "object_lock_enabled should be true when set, with versioning_enabled left at its default (true)"
  }
}

run "object_lock_without_versioning_fails" {
  command = plan

  variables {
    object_lock_enabled = true
    versioning_enabled  = false
  }

  expect_failures = [aws_s3_bucket.primary]
}
