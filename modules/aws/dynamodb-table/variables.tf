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

variable "global_secondary_indexes" {
  type = list(object({
    name            = string
    hash_key        = string
    hash_key_type   = optional(string, "S")
    range_key       = optional(string)
    range_key_type  = optional(string, "S")
    projection_type = optional(string, "ALL")
  }))
  description = "Global secondary indexes. Each entry's hash_key/range_key become table attributes automatically — do not redeclare them via hash_key/range_key above unless they're also the table's own key."
  default     = []

  validation {
    condition     = alltrue([for g in var.global_secondary_indexes : contains(["ALL", "KEYS_ONLY"], g.projection_type)])
    error_message = "every global_secondary_indexes entry's projection_type must be ALL or KEYS_ONLY. INCLUDE (with its required non_key_attributes list) is not supported by this module."
  }
}

variable "ttl_attribute" {
  type        = string
  description = "Attribute name DynamoDB uses for item expiry (TTL). Leave null to disable TTL."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the table."
  default     = {}
}
