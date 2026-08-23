# SC-28: kms_master_key_id is always set, no opt-out — defaults to the
# AWS-managed alias/aws/sns key when var.kms_key_id is null. See
# policy/aws/modules/cloudwatch.rego for the plan-time check that also
# catches a topic someone writes by hand instead of through this module.
#
# Skipped entirely when var.existing_topic_arn is set: that topic already
# exists and is owned elsewhere, so this module has nothing to encrypt. The
# rego rule is unaffected either way — it fires on planned aws_sns_topic
# resources, and this plans none in that case.
resource "aws_sns_topic" "alerts" {
  count             = var.existing_topic_arn == null ? 1 : 0
  name              = "${var.alarm_name}-alerts"
  kms_master_key_id = coalesce(var.kms_key_id, "alias/aws/sns")
  tags              = var.tags
}

# Giving aws_sns_topic.alerts a count above changes its address from
# `aws_sns_topic.alerts` to `aws_sns_topic.alerts[0]`. Without this, every
# consumer upgrading to this version would plan a destroy-and-recreate of a
# live alert topic — taking its subscriptions (each of which needs a fresh
# email confirmation click) with it. This makes the upgrade a no-op state move
# instead.
moved {
  from = aws_sns_topic.alerts
  to   = aws_sns_topic.alerts[0]
}

locals {
  # The one topic every notifying resource below points at, whether this module
  # created it or a caller passed one in.
  topic_arn = coalesce(var.existing_topic_arn, one(aws_sns_topic.alerts[*].arn))
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != null ? 1 : 0
  topic_arn = local.topic_arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Turns a log line into the metric the alarm below watches, so one module
# instance is a coherent filter -> metric -> alarm -> topic unit rather than a
# hand-written filter wired to a module alarm by matching strings.
#
# namespace/metric_name are deliberately the module's existing alarm inputs
# rather than separate ones: the alarm has to watch exactly what the filter
# publishes, and two sets of inputs would let those drift apart silently.
resource "aws_cloudwatch_log_metric_filter" "primary" {
  # Both, not just log_group_name: with only one set this must stay at count 0
  # so the alarm's precondition below is what reports the mistake. Keying on
  # log_group_name alone plans a filter with a null `pattern`, and the provider
  # rejects that first with a bare "Missing required argument".
  count          = var.log_group_name != null && var.log_filter_pattern != null ? 1 : 0
  name           = var.alarm_name
  log_group_name = var.log_group_name
  pattern        = var.log_filter_pattern

  metric_transformation {
    name      = var.metric_name
    namespace = var.namespace
    value     = "1"

    # Reports 0 for a period with no matching line, rather than publishing
    # nothing. Without this the metric only exists once it has first fired, so
    # the alarm sits in INSUFFICIENT_DATA until then and treat_missing_data has
    # to carry weight it shouldn't need to.
    default_value = "0"
  }
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

  alarm_actions = [local.topic_arn]
  ok_actions    = [local.topic_arn]

  tags = var.tags

  # Lives here, not on aws_cloudwatch_log_metric_filter: that resource is
  # count = 0 in exactly the misconfiguration this catches (log_filter_pattern
  # set, log_group_name not), so a precondition there would never evaluate.
  # This alarm is always created, so this always runs.
  #
  # A precondition rather than a variable validation block because cross-variable
  # validation needs Terraform >= 1.9 and this module floors at 1.7 — same
  # reasoning as lambda-function-url's `qualifier` (1.12.0).
  lifecycle {
    precondition {
      condition     = (var.log_group_name == null) == (var.log_filter_pattern == null)
      error_message = "log_group_name and log_filter_pattern must be set together: one names the log group to filter, the other what to match in it. Set both to publish a log-based metric, or neither to alarm on an existing metric."
    }
  }
}
