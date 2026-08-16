output "alarm_arn" { value = aws_cloudwatch_metric_alarm.primary.arn }
output "alarm_name" { value = aws_cloudwatch_metric_alarm.primary.alarm_name }
output "topic_arn" { value = aws_sns_topic.alerts.arn }
