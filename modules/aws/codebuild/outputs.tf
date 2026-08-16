output "project_name" { value = aws_codebuild_project.primary.name }
output "project_arn" { value = aws_codebuild_project.primary.arn }
output "role_arn" { value = aws_iam_role.primary.arn }
output "log_group_name" { value = aws_cloudwatch_log_group.primary.name }
