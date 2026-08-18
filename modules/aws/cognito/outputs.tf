output "user_pool_id" { value = aws_cognito_user_pool.primary.id }
output "user_pool_arn" { value = aws_cognito_user_pool.primary.arn }
output "user_pool_client_id" { value = aws_cognito_user_pool_client.primary.id }
output "user_pool_endpoint" { value = aws_cognito_user_pool.primary.endpoint }

output "hosted_ui_domain" {
  description = "The Hosted UI's base domain (null unless hosted_ui_domain_prefix is set) — build authorize/token/logout URLs as https://<hosted_ui_domain>/oauth2/authorize etc."
  value = (
    var.hosted_ui_domain_prefix != null
    ? "${aws_cognito_user_pool_domain.primary[0].domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
    : null
  )
}
