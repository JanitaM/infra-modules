variable "role_name" {
  type        = string
  description = "IAM role name."
}

variable "description" {
  type        = string
  description = "Role description."
  default     = ""
}

variable "assume_role_policy" {
  type        = string
  description = "Trust policy JSON (e.g. from aws_iam_policy_document) naming which principal can assume this role. No default — every role must state explicitly who can assume it."
}

variable "policy_arns" {
  type        = list(string)
  description = "ARNs of existing managed or customer policies to attach, e.g. the read_policy_arn/send_policy_arn output of another module in this repo. This module does not author policy documents itself."
  default     = []
}

variable "max_session_duration" {
  type        = number
  description = "Maximum session duration in seconds for credentials assuming this role."
  default     = 3600
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the role."
  default     = {}
}
