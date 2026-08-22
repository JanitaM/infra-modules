output "trail_arn" { value = aws_cloudtrail.primary.arn }
output "trail_id" { value = aws_cloudtrail.primary.id }
output "bucket_id" { value = module.log_bucket.bucket_id }
output "bucket_arn" { value = module.log_bucket.bucket_arn }
