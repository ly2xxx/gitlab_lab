variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "application_name" {
  description = "Application name used for resource naming"
  type        = string
}

variable "trusted_account_ids" {
  description = "External AWS account IDs allowed to assume the role (MFA enforced)"
  type        = list(string)
  default     = []
}

variable "app_permissions" {
  description = "IAM permission statements for the application policy"
  type = list(object({
    sid       = optional(string, "")
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "enable_permission_boundary" {
  description = "Attach a permission boundary to the application role"
  type        = bool
  default     = true
}

variable "developer_readonly_services" {
  description = "AWS service prefixes for developer read-only policy"
  type        = list(string)
  default     = ["s3", "ec2", "rds", "cloudwatch", "logs", "ssm"]
}

variable "admin_managed_policy_arns" {
  description = "AWS managed policy ARNs to attach to the admin group"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
