variable "table_name" {
  type        = string
  description = "DynamoDB table name."
}

variable "hash_key" {
  type        = string
  description = "Partition key attribute name."
}

variable "hash_key_type" {
  type        = string
  description = "Partition key attribute type (S, N, or B)."
  default     = "S"
}

variable "range_key" {
  type        = string
  description = "Sort key attribute name. Leave empty for a hash-key-only table."
  default     = ""
}

variable "range_key_type" {
  type        = string
  description = "Sort key attribute type (S, N, or B). Only used when range_key is set."
  default     = "S"
}

variable "billing_mode" {
  type        = string
  description = "PAY_PER_REQUEST or PROVISIONED."
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the table."
  default     = {}
}
