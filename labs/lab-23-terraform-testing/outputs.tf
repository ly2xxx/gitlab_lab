output "role_arn" {
  description = "ARN of the application service role"
  value       = module.rbac.role_arn
}

output "role_name" {
  description = "Name of the application service role"
  value       = module.rbac.role_name
}

output "policy_arn" {
  description = "ARN of the application IAM policy"
  value       = module.rbac.policy_arn
}

output "permission_boundary_arn" {
  description = "ARN of the permission boundary policy (null when disabled)"
  value       = module.rbac.permission_boundary_arn
}

output "developer_group_name" {
  description = "Name of the developer read-only IAM group"
  value       = module.rbac.developer_group_name
}

output "admin_group_name" {
  description = "Name of the admin IAM group"
  value       = module.rbac.admin_group_name
}

output "rbac_summary" {
  description = "Summary map of all RBAC resources created"
  value = {
    role             = module.rbac.role_name
    policy           = module.rbac.policy_arn
    developer_group  = module.rbac.developer_group_name
    admin_group      = module.rbac.admin_group_name
    boundary_enabled = var.enable_permission_boundary
  }
}
