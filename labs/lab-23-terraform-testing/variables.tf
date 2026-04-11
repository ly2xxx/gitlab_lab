variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "application_name" {
  description = "Application name used in resource naming and tagging"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", var.application_name))
    error_message = "Application name must be 3-30 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
}

variable "trusted_account_ids" {
  description = "AWS account IDs permitted to assume the application role via cross-account trust (MFA enforced)"
  type        = list(string)
  default     = []
}

variable "app_permissions" {
  description = "List of IAM permission statements for the application service role"
  type = list(object({
    sid       = optional(string, "")
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []

  validation {
    condition     = alltrue([for p in var.app_permissions : contains(["Allow", "Deny"], p.effect)])
    error_message = "Each permission statement 'effect' must be 'Allow' or 'Deny'."
  }

  validation {
    condition = alltrue([
      for p in var.app_permissions :
      !anytrue([for a in p.actions : a == "iam:*" || a == "*"])
    ])
    error_message = "Wildcard IAM actions (iam:* or *) are not permitted. Use least-privilege actions."
  }
}

variable "enable_permission_boundary" {
  description = "Attach a permission boundary to the application role to cap maximum permissions (recommended for prod)"
  type        = bool
  default     = true
}

variable "developer_readonly_services" {
  description = "AWS service prefixes that developers can use for read-only operations"
  type        = list(string)
  default     = ["s3", "ec2", "rds", "cloudwatch", "logs", "ssm"]
}

variable "admin_managed_policy_arns" {
  description = "ARNs of AWS managed policies to attach to the admin group"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
