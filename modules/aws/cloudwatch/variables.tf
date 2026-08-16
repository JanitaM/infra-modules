variable "alarm_name" {
  type        = string
  description = "Alarm name. Also used to derive the SNS topic name (\"<alarm_name>-alerts\")."
}

variable "alarm_description" {
  type        = string
  description = "Alarm description."
  default     = ""
}

variable "namespace" {
  type        = string
  description = "Metric namespace, e.g. \"AWS/Lambda\"."
}

variable "metric_name" {
  type        = string
  description = "Metric name, e.g. \"Errors\"."
}

variable "statistic" {
  type        = string
  description = "Statistic to apply to the metric."
  default     = "Sum"

  validation {
    condition     = contains(["SampleCount", "Average", "Sum", "Minimum", "Maximum"], var.statistic)
    error_message = "statistic must be SampleCount, Average, Sum, Minimum, or Maximum."
  }
}

variable "period" {
  type        = number
  description = "Evaluation period, in seconds."
  default     = 300
}

variable "evaluation_periods" {
  type        = number
  description = "Number of periods over which data is compared to the threshold."
  default     = 1
}

variable "threshold" {
  type        = number
  description = "Value the metric is compared against."
}

variable "comparison_operator" {
  type        = string
  description = "How the metric is compared to the threshold."

  validation {
    condition = contains([
      "GreaterThanOrEqualToThreshold", "GreaterThanThreshold",
      "LessThanThreshold", "LessThanOrEqualToThreshold",
    ], var.comparison_operator)
    error_message = "comparison_operator must be GreaterThanOrEqualToThreshold, GreaterThanThreshold, LessThanThreshold, or LessThanOrEqualToThreshold."
  }
}

variable "dimensions" {
  type        = map(string)
  description = "Metric dimensions, e.g. { FunctionName = \"my-function\" }."
  default     = {}
}

variable "treat_missing_data" {
  type        = string
  description = "How the alarm handles missing data points."
  default     = "missing"

  validation {
    condition     = contains(["missing", "ignore", "breaching", "notBreaching"], var.treat_missing_data)
    error_message = "treat_missing_data must be missing, ignore, breaching, or notBreaching."
  }
}

variable "alert_email" {
  type        = string
  description = "Email address subscribed to the alert topic. Leave null to skip creating a subscription (e.g. when a project subscribes its own endpoint separately)."
  default     = null
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID or ARN to encrypt the SNS alert topic with. Defaults to the AWS-managed alias/aws/sns key when null."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the alarm and its alert topic."
  default     = {}
}
