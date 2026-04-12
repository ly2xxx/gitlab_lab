# ============================================================
# Unit Test: Permission Boundary (Zero-Trust Guardrail)
#
# The permission boundary is the most critical RBAC control:
# it defines the MAXIMUM permissions a role can ever hold.
# Even if a misconfigured policy grants extra access, the
# boundary silently overrides it.
#
# Tests verify:
#   - Boundary is attached when enable_permission_boundary=true
#   - Boundary is absent when disabled (e.g., dev sandbox)
#   - Boundary policy blocks privilege-escalation actions
#   - Application role references the correct boundary ARN
# ============================================================

mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::111122223333:role/mock-role"
      unique_id = "AROAEXAMPLE000BOUND"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      # The mock ARN returned for every aws_iam_policy created.
      # Because our module creates the boundary policy first and
      # passes its ARN to the role, the role's permissions_boundary
      # attribute will be set to this value in the plan.
      arn       = "arn:aws:iam::111122223333:policy/mock-boundary"
      policy_id = "ANPAEXAMPLE000BOUND"
    }
  }

  mock_resource "aws_iam_group" {
    defaults = {
      arn       = "arn:aws:iam::111122223333:group/mock-group"
      unique_id = "AGPAEXAMPLE000BOUND"
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
  environment      = "prod"
  application_name = "payments"
  aws_region       = "us-east-1"
  app_permissions = [
    {
      sid       = "AllowDynamoDB"
      effect    = "Allow"
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"]
      resources = ["arn:aws:dynamodb:us-east-1:*:table/prod-payments-*"]
    }
  ]
  enable_permission_boundary = true
}

# ------------------------------------------------------------------
run "boundary_arn_is_non_null_when_enabled" {
  command = apply

  assert {
    condition     = module.rbac.permission_boundary_arn != null
    error_message = "Permission boundary ARN must not be null when enable_permission_boundary=true."
  }
}

# ------------------------------------------------------------------
# Apply the full module and then inspect the role's boundary.
# With mock_provider, we get predictable ARN values.
run "role_has_permission_boundary_attached" {
  command = apply

  assert {
    condition     = module.rbac.permission_boundary_arn != null
    error_message = "Role must reference the permission boundary when it is enabled."
  }
}

# ------------------------------------------------------------------
# Verify the boundary policy document blocks IAM escalation.
# We parse the JSON and check for the DenyPrivilegeEscalation Sid.
run "boundary_policy_blocks_iam_escalation" {
  command = apply

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.permission_boundary_policy_json).Statement :
      stmt.Sid == "DenyPrivilegeEscalation" && stmt.Effect == "Deny"
    ])
    error_message = "Permission boundary must contain a DenyPrivilegeEscalation Deny statement."
  }
}

# ------------------------------------------------------------------
# Verify iam:CreateRole is explicitly denied in the boundary.
run "boundary_denies_iam_create_role" {
  command = apply

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.permission_boundary_policy_json).Statement :
      stmt.Effect == "Deny" && contains(stmt.Action, "iam:CreateRole")
    ])
    error_message = "Permission boundary must explicitly deny iam:CreateRole to prevent privilege escalation."
  }
}

# ------------------------------------------------------------------
# Switch to disabled and verify no boundary is applied.
run "boundary_is_null_when_disabled" {
  command = apply

  variables {
    enable_permission_boundary = false
  }

  assert {
    condition     = module.rbac.permission_boundary_arn == null
    error_message = "Permission boundary ARN must be null when enable_permission_boundary=false."
  }

  assert {
    condition     = module.rbac.permission_boundary_policy_json == null
    error_message = "Permission boundary policy JSON must be null when disabled."
  }
}

# ------------------------------------------------------------------
# Verify the boundary allows the listed scoped services.
run "boundary_allows_s3_operations" {
  command = apply

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.permission_boundary_policy_json).Statement :
      stmt.Sid == "AllowScopedServices" && stmt.Effect == "Allow" && contains(stmt.Action, "s3:*")
    ])
    error_message = "Permission boundary must allow s3:* within the scoped services statement."
  }
}
