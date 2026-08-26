variable "project_name" {
  type        = string
  description = "CodeBuild project name."
}

variable "description" {
  type        = string
  description = "Project description."
  default     = ""
}

variable "source_type" {
  type        = string
  description = "Source provider type."

  validation {
    condition     = contains(["GITHUB", "S3"], var.source_type)
    error_message = "source_type must be GITHUB or S3."
  }
}

variable "source_location" {
  type        = string
  description = "Source location: a GitHub repo URL when source_type is GITHUB, or a bucket/key path when source_type is S3."
}

variable "source_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket in source_location. Required when source_type is S3, used only to scope IAM read access."
  default     = null
}

variable "buildspec" {
  type        = string
  description = "Path to the buildspec file within the source. Leave empty to use buildspec.yml at the source root."
  default     = ""
}

variable "environment_compute_type" {
  type        = string
  description = "Build environment compute type."
  default     = "BUILD_GENERAL1_SMALL"

  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE",
    ], var.environment_compute_type)
    error_message = "environment_compute_type must be BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, or BUILD_GENERAL1_LARGE."
  }
}

variable "environment_image" {
  type        = string
  description = "Build environment Docker image."
  default     = "aws/codebuild/standard:7.0"
}

variable "environment_type" {
  type        = string
  description = "Build environment type."
  default     = "LINUX_CONTAINER"

  validation {
    condition     = contains(["LINUX_CONTAINER", "LINUX_GPU_CONTAINER", "ARM_CONTAINER"], var.environment_type)
    error_message = "environment_type must be LINUX_CONTAINER, LINUX_GPU_CONTAINER, or ARM_CONTAINER."
  }
}

variable "privileged_mode" {
  type        = bool
  description = "Enables Docker-in-Docker for building container images. Defaults to false; setting true is blocked by policy/aws/modules/codebuild.rego, which is mandatory and unpinned — enabling it for real requires changing that shared policy, not this variable alone."
  default     = false
}

variable "environment_variables" {
  type        = map(string)
  description = "Plaintext environment variables passed to the build. Do not put secrets here — Secrets Manager/SSM integration is not yet supported by this module."
  default     = {}
}

variable "artifact_type" {
  type        = string
  description = "Build artifact output type."
  default     = "NO_ARTIFACTS"

  validation {
    condition     = contains(["NO_ARTIFACTS", "S3"], var.artifact_type)
    error_message = "artifact_type must be NO_ARTIFACTS or S3."
  }
}

variable "artifact_bucket_name" {
  type        = string
  description = "Name of the S3 bucket to write artifacts to. Required when artifact_type is S3."
  default     = null
}

variable "artifact_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket to write artifacts to. Required when artifact_type is S3, used only to scope IAM write access."
  default     = null
}

variable "cache_type" {
  type        = string
  description = "Build cache type."
  default     = "NO_CACHE"

  validation {
    condition     = contains(["NO_CACHE", "S3"], var.cache_type)
    error_message = "cache_type must be NO_CACHE or S3."
  }
}

variable "cache_bucket_name" {
  type        = string
  description = "Name of the S3 bucket (optionally bucket/prefix) to store the build cache in. Required when cache_type is S3."
  default     = null
}

variable "cache_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket in cache_bucket_name. Required when cache_type is S3, used only to scope IAM read/write access."
  default     = null
}

variable "build_timeout" {
  type        = number
  description = "Build timeout, in minutes."
  default     = 15
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention for this project's build logs."
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the project, its role, and its log group."
  default     = {}
}

check "source_bucket_required" {
  assert {
    condition     = var.source_type != "S3" || var.source_bucket_arn != null
    error_message = "source_bucket_arn is required when source_type is S3."
  }
}

check "artifact_bucket_required" {
  assert {
    condition     = var.artifact_type != "S3" || (var.artifact_bucket_name != null && var.artifact_bucket_arn != null)
    error_message = "artifact_bucket_name and artifact_bucket_arn are required when artifact_type is S3."
  }
}

check "cache_bucket_required" {
  assert {
    condition     = var.cache_type != "S3" || (var.cache_bucket_name != null && var.cache_bucket_arn != null)
    error_message = "cache_bucket_name and cache_bucket_arn are required when cache_type is S3."
  }
}
