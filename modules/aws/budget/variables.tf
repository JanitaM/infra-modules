variable "budget_name" {
  type        = string
  description = "Budget name."
}

variable "limit_amount" {
  type        = string
  description = "Spend limit, as a decimal string (e.g. \"100.0\")."
}

variable "limit_unit" {
  type        = string
  description = "Currency for limit_amount."
  default     = "USD"
}

variable "time_unit" {
  type        = string
  description = "Budget period."
  default     = "MONTHLY"

  validation {
    condition     = contains(["DAILY", "MONTHLY", "QUARTERLY", "ANNUALLY"], var.time_unit)
    error_message = "time_unit must be DAILY, MONTHLY, QUARTERLY, or ANNUALLY."
  }
}

variable "alert_emails" {
  type        = list(string)
  description = "Email addresses notified when the budget threshold is crossed. Must be non-empty — a budget with no notification is silently useless."

  validation {
    condition     = length(var.alert_emails) > 0
    error_message = "alert_emails must contain at least one address."
  }
}

variable "sns_topic_arn" {
  type        = string
  description = "Additional SNS topic notified alongside alert_emails, e.g. the topic_arn output of the cloudwatch module. Leave null to notify by email only."
  default     = null
}

variable "threshold_percentage" {
  type        = number
  description = "Percentage of limit_amount that triggers the notification."
  default     = 80
}

variable "comparison_operator" {
  type        = string
  description = "How actual/forecasted spend is compared to the threshold."
  default     = "GREATER_THAN"

  validation {
    condition     = contains(["GREATER_THAN", "LESS_THAN", "EQUAL_TO"], var.comparison_operator)
    error_message = "comparison_operator must be GREATER_THAN, LESS_THAN, or EQUAL_TO."
  }
}

variable "notification_type" {
  type        = string
  description = "Whether the threshold applies to actual or forecasted spend."
  default     = "ACTUAL"

  validation {
    condition     = contains(["ACTUAL", "FORECASTED"], var.notification_type)
    error_message = "notification_type must be ACTUAL or FORECASTED."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the budget."
  default     = {}
}
