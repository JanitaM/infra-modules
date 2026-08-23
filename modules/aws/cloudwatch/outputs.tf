output "alarm_arn" { value = aws_cloudwatch_metric_alarm.primary.arn }
output "alarm_name" { value = aws_cloudwatch_metric_alarm.primary.alarm_name }

# The topic this alarm notifies, whether the module created it or the caller
# passed one in via existing_topic_arn — so a consumer chaining another alarm
# onto the same topic can always read it from here.
output "topic_arn" { value = local.topic_arn }

# null when no log-based metric filter was requested.
output "log_metric_filter_name" { value = one(aws_cloudwatch_log_metric_filter.primary[*].name) }
