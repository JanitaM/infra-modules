output "parameter_name" { value = aws_ssm_parameter.primary.name }
output "parameter_arn" { value = aws_ssm_parameter.primary.arn }
output "version" { value = aws_ssm_parameter.primary.version }
output "read_policy_arn" { value = aws_iam_policy.read.arn }
