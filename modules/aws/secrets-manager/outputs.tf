output "secret_id" { value = aws_secretsmanager_secret.primary.id }
output "secret_arn" { value = aws_secretsmanager_secret.primary.arn }
output "secret_name" { value = aws_secretsmanager_secret.primary.name }
output "read_policy_arn" { value = aws_iam_policy.read.arn }
