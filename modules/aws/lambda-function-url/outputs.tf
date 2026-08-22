output "function_arn" { value = aws_lambda_function.primary.arn }
output "function_name" { value = aws_lambda_function.primary.function_name }
output "function_url" { value = aws_lambda_function_url.primary.function_url }
output "role_arn" { value = aws_iam_role.primary.arn }
output "published_version" {
  description = "The Lambda version published by this apply. \"$LATEST\" when publish is false."
  value       = aws_lambda_function.primary.version
}
output "alias_arn" {
  description = "ARN of the alias tracking published_version. null when publish is false."
  value       = var.publish ? aws_lambda_alias.primary[0].arn : null
}
