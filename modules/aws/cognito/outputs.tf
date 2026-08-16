output "user_pool_id" { value = aws_cognito_user_pool.primary.id }
output "user_pool_arn" { value = aws_cognito_user_pool.primary.arn }
output "user_pool_client_id" { value = aws_cognito_user_pool_client.primary.id }
output "user_pool_endpoint" { value = aws_cognito_user_pool.primary.endpoint }
