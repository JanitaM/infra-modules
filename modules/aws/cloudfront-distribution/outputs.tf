output "distribution_id" { value = aws_cloudfront_distribution.primary.id }
output "distribution_arn" { value = aws_cloudfront_distribution.primary.arn }
output "domain_name" { value = aws_cloudfront_distribution.primary.domain_name }
output "hosted_zone_id" { value = aws_cloudfront_distribution.primary.hosted_zone_id }
