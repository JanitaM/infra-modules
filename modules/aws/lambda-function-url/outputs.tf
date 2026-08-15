output "function_arn"  { value = aws_lambda_function.primary.arn }
output "function_name" { value = aws_lambda_function.primary.function_name }
output "function_url"  { value = aws_lambda_function_url.primary.function_url }
output "role_arn"      { value = aws_iam_role.primary.arn }
