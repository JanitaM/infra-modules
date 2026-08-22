data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Built by hand rather than referenced from aws_cloudtrail.primary.arn:
# the bucket policy needs the trail's ARN in its SourceArn condition, and the
# trail needs the bucket policy to exist first (depends_on below) so
# CloudTrail's own delivery check at creation time doesn't fail — referencing
# the resource attribute directly would make those two facts a dependency
# cycle. A CloudTrail trail ARN is fully determined by account, region and
# name, so this is safe to precompute.
locals {
  trail_arn = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"
}

# Reuses this repo's own s3-bucket module for the log bucket, inheriting its
# always-on public-access-block and SSE-S3 encryption rather than
# re-implementing either here.
module "log_bucket" {
  source = "../s3-bucket"

  bucket_name        = var.bucket_name
  versioning_enabled = true
  tags               = var.tags
}

# AU-9: grants CloudTrail only what it needs to deliver logs, and only for
# this specific trail — both statements condition on this trail's own ARN, so
# the policy can't be reused by any other CloudTrail trail in any account.
resource "aws_s3_bucket_policy" "log_bucket" {
  bucket = module.log_bucket.bucket_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudTrailGetBucketAcl"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = module.log_bucket.bucket_arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = local.trail_arn
          }
        }
      },
      {
        Sid       = "AllowCloudTrailPutObject"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${module.log_bucket.bucket_arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = local.trail_arn
          }
        }
      }
    ]
  })
}

# AU-2: the audit trail itself. Log file validation is always on — an audit
# log that can't prove it wasn't tampered with defeats its own purpose, so
# unlike most settings in this module it is not exposed as an opt-out.
resource "aws_cloudtrail" "primary" {
  name                          = var.trail_name
  s3_bucket_name                = module.log_bucket.bucket_id
  is_multi_region_trail         = var.is_multi_region_trail
  include_global_service_events = var.include_global_service_events
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_id
  tags                          = var.tags

  dynamic "event_selector" {
    for_each = var.event_selector
    content {
      read_write_type           = event_selector.value.read_write_type
      include_management_events = event_selector.value.include_management_events

      dynamic "data_resource" {
        for_each = event_selector.value.data_resources
        content {
          type   = data_resource.value.type
          values = data_resource.value.values
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.log_bucket]
}
