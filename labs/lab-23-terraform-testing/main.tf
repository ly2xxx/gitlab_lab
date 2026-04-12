# ============================================================
# Lab 23 - Terraform Declarative Testing: RBAC Demo
#
# This root module wires together the rbac child module.
# Tests are in tests/ and run with: terraform test
# ============================================================

module "rbac" {
  source = "./modules/rbac"

  environment                 = var.environment
  application_name            = var.application_name
  trusted_account_ids         = var.trusted_account_ids
  app_permissions             = var.app_permissions
  enable_permission_boundary  = var.enable_permission_boundary
  developer_readonly_services = var.developer_readonly_services
  admin_managed_policy_arns   = var.admin_managed_policy_arns
}
