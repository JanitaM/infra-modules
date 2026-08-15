output "bucket_id"  { value = aws_s3_bucket.primary.id }
output "bucket_arn" { value = aws_s3_bucket.primary.arn }

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.primary.bucket_regional_domain_name
}
