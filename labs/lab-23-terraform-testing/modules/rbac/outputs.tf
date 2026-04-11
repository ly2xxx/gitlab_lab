output "role_arn" {
  description = "ARN of the application service role"
  value       = aws_iam_role.application_role.arn
}

output "role_name" {
  description = "Name of the application service role"
  value       = aws_iam_role.application_role.name
}

output "role_assume_policy_json" {
  description = "Trust policy JSON of the application role (useful for testing cross-account assumptions)"
  value       = aws_iam_role.application_role.assume_role_policy
}

output "policy_arn" {
  description = "ARN of the application IAM policy"
  value       = aws_iam_policy.application_policy.arn
}

output "application_policy_json" {
  description = "JSON document of the application policy (exposed for test assertions)"
  value       = aws_iam_policy.application_policy.policy
}

output "permission_boundary_arn" {
  description = "ARN of the permission boundary policy; null when disabled"
  value       = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null
}

output "permission_boundary_policy_json" {
  description = "JSON document of the permission boundary (null when disabled)"
  value       = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].policy : null
}

output "developer_group_name" {
  description = "Name of the developer read-only IAM group"
  value       = aws_iam_group.developers.name
}

output "developer_group_arn" {
  description = "ARN of the developer IAM group"
  value       = aws_iam_group.developers.arn
}

output "developer_policy_json" {
  description = "JSON document of the developer read-only policy (exposed for test assertions)"
  value       = aws_iam_policy.developer_readonly.policy
}

output "admin_group_name" {
  description = "Name of the admin IAM group"
  value       = aws_iam_group.admins.name
}

output "admin_group_arn" {
  description = "ARN of the admin IAM group"
  value       = aws_iam_group.admins.arn
}
