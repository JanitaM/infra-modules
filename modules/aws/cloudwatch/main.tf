# SC-28: kms_master_key_id is always set, no opt-out — defaults to the
# AWS-managed alias/aws/sns key when var.kms_key_id is null. See
# policy/aws/modules/cloudwatch.rego for the plan-time check that also
# catches a topic someone writes by hand instead of through this module.
resource "aws_sns_topic" "alerts" {
  name              = "${var.alarm_name}-alerts"
  kms_master_key_id = coalesce(var.kms_key_id, "alias/aws/sns")
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != null ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "primary" {
  alarm_name          = var.alarm_name
  alarm_description   = var.alarm_description
  namespace           = var.namespace
  metric_name         = var.metric_name
  statistic           = var.statistic
  period              = var.period
  evaluation_periods  = var.evaluation_periods
  threshold           = var.threshold
  comparison_operator = var.comparison_operator
  dimensions          = var.dimensions
  treat_missing_data  = var.treat_missing_data

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}
