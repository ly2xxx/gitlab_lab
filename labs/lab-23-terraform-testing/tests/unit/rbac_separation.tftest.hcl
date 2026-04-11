# ============================================================
# Unit Test: RBAC Separation of Duties
#
# Validates that developer and admin groups are properly
# segregated and that developer policy enforces read-only
# access with explicit write denials.
#
# RBAC Principle: "Need to Know" + "Least Privilege"
#   - Developers see state, cannot change it
#   - Admins have elevated access via managed policies
#   - Application role holds only what the service needs
#   - Groups and roles are distinct, non-overlapping identities
#
# Tests also validate the application policy defaults:
#   - No permissions provided → deny-all (safe default)
#   - Explicit permissions → only those actions allowed
# ============================================================

mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::111122223333:role/mock-role"
      unique_id = "AROAEXAMPLE000RBAC"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn       = "arn:aws:iam::111122223333:policy/mock-policy"
      policy_id = "ANPAEXAMPLE000RBAC"
    }
  }

  mock_resource "aws_iam_group" {
    defaults = {
      arn       = "arn:aws:iam::111122223333:group/mock-group"
      unique_id = "AGPAEXAMPLE000RBAC"
    }
  }

  mock_resource "aws_iam_role_policy_attachment" {
    defaults = {}
  }

  mock_resource "aws_iam_group_policy_attachment" {
    defaults = {}
  }
}

variables {
  environment      = "dev"
  application_name = "inventory"
  aws_region       = "us-east-1"
  app_permissions  = []
  enable_permission_boundary      = true
  developer_readonly_services     = ["s3", "ec2", "rds"]
  admin_managed_policy_arns       = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

# ------------------------------------------------------------------
# Developer and admin groups must be different resources.
run "developer_and_admin_groups_are_distinct" {
  command = plan

  assert {
    condition     = module.rbac.developer_group_name != module.rbac.admin_group_name
    error_message = "Developer and admin groups must have different names. Got same: ${module.rbac.developer_group_name}"
  }
}

# ------------------------------------------------------------------
# Developer group name must contain "developer" (not "admin")
# to make IAM conditions based on group names unambiguous.
run "developer_group_is_not_admin_group" {
  command = plan

  assert {
    condition     = !strcontains(module.rbac.developer_group_name, "admin")
    error_message = "Developer group name must not contain 'admin'. Got: ${module.rbac.developer_group_name}"
  }

  assert {
    condition     = !strcontains(module.rbac.admin_group_name, "developer")
    error_message = "Admin group name must not contain 'developer'. Got: ${module.rbac.admin_group_name}"
  }
}

# ------------------------------------------------------------------
# Developer policy must have an explicit Deny for mutations.
# Relying only on "no Allow" is insufficient — an SCP or
# another policy could inadvertently grant write access.
run "developer_policy_has_deny_mutations_statement" {
  command = apply

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.developer_policy_json).Statement :
      stmt.Sid == "DenyAllMutations" && stmt.Effect == "Deny"
    ])
    error_message = "Developer policy must contain a DenyAllMutations Deny statement."
  }
}

# ------------------------------------------------------------------
# Developer policy must have an Allow for read operations.
run "developer_policy_allows_read_operations" {
  command = apply

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.developer_policy_json).Statement :
      stmt.Sid == "AllowReadOperations" && stmt.Effect == "Allow"
    ])
    error_message = "Developer policy must contain an AllowReadOperations Allow statement."
  }
}

# ------------------------------------------------------------------
# When no app_permissions are provided, the application policy
# must default to Deny All to prevent accidental open access.
run "application_policy_defaults_to_deny_all" {
  command = apply

  variables {
    app_permissions = []
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.application_policy_json).Statement :
      stmt.Sid == "DefaultDenyAll" && stmt.Effect == "Deny"
    ])
    error_message = "Application policy must default to DefaultDenyAll when no permissions are specified."
  }
}

# ------------------------------------------------------------------
# When permissions are explicitly provided, the policy must
# NOT contain the default deny-all (it should use the provided statements).
run "application_policy_uses_provided_permissions" {
  command = apply

  variables {
    app_permissions = [
      {
        sid       = "AllowS3Read"
        effect    = "Allow"
        actions   = ["s3:GetObject", "s3:ListBucket"]
        resources = ["arn:aws:s3:::dev-inventory-data/*"]
      }
    ]
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.application_policy_json).Statement :
      stmt.Sid == "AllowS3Read"
    ])
    error_message = "Application policy must include the user-provided 'AllowS3Read' statement."
  }

  assert {
    condition = !anytrue([
      for stmt in jsondecode(module.rbac.application_policy_json).Statement :
      stmt.Sid == "DefaultDenyAll"
    ])
    error_message = "Application policy must not contain DefaultDenyAll when explicit permissions are provided."
  }
}

# ------------------------------------------------------------------
# Cross-account trust must not exist when trusted_account_ids is empty.
run "no_cross_account_trust_when_no_accounts_provided" {
  command = apply

  variables {
    trusted_account_ids = []
  }

  assert {
    condition = length([
      for stmt in jsondecode(module.rbac.role_assume_policy_json).Statement :
      stmt if stmt.Sid == "AllowCrossAccountWithMFA"
    ]) == 0
    error_message = "Trust policy must not have cross-account statement when trusted_account_ids is empty."
  }
}

# ------------------------------------------------------------------
# Cross-account trust must require MFA and ExternalId.
run "cross_account_trust_requires_mfa_and_external_id" {
  command = apply

  variables {
    trusted_account_ids = ["999988887777"]
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.role_assume_policy_json).Statement :
      stmt.Sid == "AllowCrossAccountWithMFA" &&
      try(stmt.Condition.Bool["aws:MultiFactorAuthPresent"] == "true", false)
    ])
    error_message = "Cross-account trust must enforce MFA via aws:MultiFactorAuthPresent condition."
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.role_assume_policy_json).Statement :
      stmt.Sid == "AllowCrossAccountWithMFA" &&
      try(stmt.Condition.StringEquals["sts:ExternalId"] == "dev-inventory", false)
    ])
    error_message = "Cross-account trust must include ExternalId condition to prevent confused deputy attacks."
  }
}
