variable "trail_name" {
  type        = string
  description = "Name of the CloudTrail trail."
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name for the log bucket this module creates. Choose a name outside any prefix a CI/deploy role already has blanket S3 access to — otherwise the role being audited can tamper with or delete its own audit trail."
}

variable "is_multi_region_trail" {
  type        = bool
  description = "Log events from every region, not just the one this trail is created in."
  default     = true
}

variable "include_global_service_events" {
  type        = bool
  description = "Include events from global services (IAM, STS, etc.), which otherwise never appear in any regional trail."
  default     = true
}

variable "event_selector" {
  type = list(object({
    read_write_type           = string
    include_management_events = bool
    data_resources = optional(list(object({
      type   = string
      values = list(string)
    })), [])
  }))
  description = "CloudTrail event selectors. Defaults to management events only, across all read/write types — the free, always-useful baseline. Data event logging (S3 object-level, Lambda invocations, etc.) is billed per event; opt in explicitly by setting data_resources."
  default = [{
    read_write_type           = "All"
    include_management_events = true
    data_resources            = []
  }]
}

variable "kms_key_id" {
  type        = string
  description = "ARN of an existing KMS key to encrypt delivered log files with. This module does not create the key — same attach-don't-author pattern as response_headers_policy_id elsewhere in this repo. Leave null to rely on the log bucket's SSE-S3 encryption (always on, via the s3-bucket module this module composes)."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the trail and its log bucket."
  default     = {}
}
