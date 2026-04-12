# ============================================================
# Unit Test: Naming Convention Enforcement
#
# Verifies that all IAM resources follow the agreed naming
# pattern: {environment}-{application_name}-{resource_type}
#
# WHY THIS MATTERS:
#   Consistent names let ops teams find resources instantly
#   and write IAM conditions that scope access by name prefix.
#
# Uses mock_provider so no AWS credentials are required.
# ============================================================

mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::111122223333:role/mock-role"
      unique_id = "AROAEXAMPLE000NAMING"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn       = "arn:aws:iam::111122223333:policy/mock-policy"
      policy_id = "ANPAEXAMPLE000NAMING"
    }
  }

  mock_resource "aws_iam_group" {
    defaults = {
      arn       = "arn:aws:iam::111122223333:group/mock-group"
      unique_id = "AGPAEXAMPLE000NAMING"
    }
  }

  mock_resource "aws_iam_role_policy_attachment" {
    defaults = {}
  }

  mock_resource "aws_iam_group_policy_attachment" {
    defaults = {}
  }
}

# Variables used across all run blocks in this file
variables {
  environment      = "staging"
  application_name = "webapp"
  aws_region       = "us-east-1"
  app_permissions = [
    {
      sid       = "AllowS3Read"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = ["arn:aws:s3:::staging-webapp-*"]
    }
  ]
  enable_permission_boundary = true
}

# ------------------------------------------------------------------
run "application_role_name_follows_convention" {
  # command = plan (default) runs a plan and checks assertions
  # without creating any real infrastructure.
  command = plan

  assert {
    condition     = module.rbac.role_name == "staging-webapp-role"
    error_message = "Role name must follow '{env}-{app}-role'. Got: ${module.rbac.role_name}"
  }
}

# ------------------------------------------------------------------
run "developer_group_name_follows_convention" {
  command = plan

  assert {
    condition     = module.rbac.developer_group_name == "staging-webapp-developers"
    error_message = "Developer group must follow '{env}-{app}-developers'. Got: ${module.rbac.developer_group_name}"
  }
}

# ------------------------------------------------------------------
run "admin_group_name_follows_convention" {
  command = plan

  assert {
    condition     = module.rbac.admin_group_name == "staging-webapp-admins"
    error_message = "Admin group must follow '{env}-{app}-admins'. Got: ${module.rbac.admin_group_name}"
  }
}

# ------------------------------------------------------------------
# Override variables for a different environment to confirm the
# naming pattern holds across all environments.
run "naming_convention_holds_in_prod" {
  command = plan

  variables {
    environment      = "prod"
    application_name = "payments"
  }

  assert {
    condition     = module.rbac.role_name == "prod-payments-role"
    error_message = "Role name must adapt to environment. Got: ${module.rbac.role_name}"
  }

  assert {
    condition     = module.rbac.developer_group_name == "prod-payments-developers"
    error_message = "Developer group must adapt to environment. Got: ${module.rbac.developer_group_name}"
  }

  assert {
    condition     = module.rbac.admin_group_name == "prod-payments-admins"
    error_message = "Admin group must adapt to environment. Got: ${module.rbac.admin_group_name}"
  }
}

# ------------------------------------------------------------------
# Verify the rbac_summary output is well-formed.
# This catches refactoring accidents where keys are renamed.
run "rbac_summary_output_has_expected_keys" {
  command = plan

  assert {
    condition     = output.rbac_summary["role"] == "staging-webapp-role"
    error_message = "rbac_summary.role should match the role name."
  }

  assert {
    condition     = output.rbac_summary["developer_group"] == "staging-webapp-developers"
    error_message = "rbac_summary.developer_group should match the developer group name."
  }

  assert {
    condition     = output.rbac_summary["admin_group"] == "staging-webapp-admins"
    error_message = "rbac_summary.admin_group should match the admin group name."
  }

  assert {
    condition     = output.rbac_summary["boundary_enabled"] == true
    error_message = "rbac_summary.boundary_enabled should reflect the variable value."
  }
}
