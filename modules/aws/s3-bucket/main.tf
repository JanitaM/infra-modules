resource "aws_s3_bucket" "primary" {
  bucket              = var.bucket_name
  object_lock_enabled = var.object_lock_enabled
  tags                = var.tags

  lifecycle {
    precondition {
      # Object Lock requires versioning, and both are set at creation time —
      # catch the invalid combination at plan, not with AWS's own apply-time
      # error.
      condition     = !var.object_lock_enabled || var.versioning_enabled
      error_message = "object_lock_enabled requires versioning_enabled = true — Object Lock cannot be enabled on an unversioned bucket."
    }
  }
}

# SC-28: Protection of information at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

# CM-6: Versioning preserves prior object states for recovery and audit.
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# AC-3: Access control, explicit deny on every public access vector.
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Opt-in only: a browser's cross-origin request (e.g. a presigned PUT from an
# app on another origin) is rejected at the preflight with no CORS policy set.
resource "aws_s3_bucket_cors_configuration" "primary" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.primary.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_origins = cors_rule.value.allowed_origins
      allowed_methods = cors_rule.value.allowed_methods
      allowed_headers = cors_rule.value.allowed_headers
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}
