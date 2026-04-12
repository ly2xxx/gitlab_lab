# ============================================================
# Integration Test: Full RBAC Deployment Scenario
#
# Simulates a realistic "production-readiness" deployment of
# RBAC for a payments microservice that:
#   - Writes to DynamoDB
#   - Reads secrets from Secrets Manager
#   - Publishes metrics to CloudWatch
#   - Is deployed to prod (boundary MUST be enabled)
#   - Allows a security account to assume role with MFA
#
# Unlike unit tests (which test isolated properties), this
# integration test validates the WHOLE system behaves
# correctly as a single composed deployment.
#
# All assertions use mock_provider — no AWS credentials needed.
# In a real pipeline you would run a separate suite against a
# real sandbox account using terraform test with actual creds.
# ============================================================

mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      arn       = "arn:aws:iam::444455556666:role/prod-payments-role"
      unique_id = "AROAEXAMPLE00INTEG"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      arn       = "arn:aws:iam::444455556666:policy/prod-payments-policy"
      policy_id = "ANPAEXAMPLE00INTEG"
    }
  }

  mock_resource "aws_iam_group" {
    defaults = {
      arn       = "arn:aws:iam::444455556666:group/prod-payments-group"
      unique_id = "AGPAEXAMPLE00INTEG"
    }
  }

  mock_resource "aws_iam_role_policy_attachment" {
    defaults = {}
  }

  mock_resource "aws_iam_group_policy_attachment" {
    defaults = {}
  }
}

# Full realistic configuration for a payments service
variables {
  environment      = "prod"
  application_name = "payments"
  aws_region       = "eu-west-1"

  # Cross-account: security tooling account can audit via assume-role
  trusted_account_ids = ["123456789012"]

  # Least-privilege: only what the service actually needs
  app_permissions = [
    {
      sid       = "AllowDynamoDBOperations"
      effect    = "Allow"
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:TransactWriteItems"]
      resources = ["arn:aws:dynamodb:eu-west-1:*:table/prod-payments-*"]
    },
    {
      sid       = "AllowSecretsManagerRead"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["arn:aws:secretsmanager:eu-west-1:*:secret:prod/payments/*"]
    },
    {
      sid       = "AllowCloudWatchMetrics"
      effect    = "Allow"
      actions   = ["cloudwatch:PutMetricData", "xray:PutTraceSegments"]
      resources = ["*"]
    },
    {
      sid       = "AllowKMSDecrypt"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = ["arn:aws:kms:eu-west-1:*:key/*"]
    },
  ]

  enable_permission_boundary = true   # mandatory for prod

  developer_readonly_services   = ["s3", "dynamodb", "cloudwatch", "logs", "xray"]
  admin_managed_policy_arns     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

# ------------------------------------------------------------------
# Smoke test: all primary outputs must be non-empty strings.
run "all_primary_outputs_are_populated" {
  command = apply

  assert {
    condition     = module.rbac.role_name != ""
    error_message = "role_name output must not be empty."
  }

  assert {
    condition     = module.rbac.policy_arn != ""
    error_message = "policy_arn output must not be empty."
  }

  assert {
    condition     = module.rbac.developer_group_name != ""
    error_message = "developer_group_name output must not be empty."
  }

  assert {
    condition     = module.rbac.admin_group_name != ""
    error_message = "admin_group_name output must not be empty."
  }
}

# ------------------------------------------------------------------
# In prod, permission boundary is mandatory.
run "prod_deployment_has_permission_boundary" {
  command = apply

  assert {
    condition     = module.rbac.permission_boundary_arn != null
    error_message = "Production deployment MUST have permission boundary enabled."
  }
}

# ------------------------------------------------------------------
# All four permission statements from variables must appear in policy.
run "application_policy_contains_all_four_permission_blocks" {
  command = apply

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.application_policy_json).Statement :
      stmt.Sid == "AllowDynamoDBOperations"
    ])
    error_message = "Application policy must include AllowDynamoDBOperations."
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.application_policy_json).Statement :
      stmt.Sid == "AllowSecretsManagerRead"
    ])
    error_message = "Application policy must include AllowSecretsManagerRead."
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.application_policy_json).Statement :
      stmt.Sid == "AllowCloudWatchMetrics"
    ])
    error_message = "Application policy must include AllowCloudWatchMetrics."
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.application_policy_json).Statement :
      stmt.Sid == "AllowKMSDecrypt"
    ])
    error_message = "Application policy must include AllowKMSDecrypt."
  }
}

# ------------------------------------------------------------------
# Security account assumption requires MFA + ExternalId.
run "security_account_trust_enforces_mfa" {
  command = apply

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.role_assume_policy_json).Statement :
      stmt.Sid == "AllowCrossAccountWithMFA" &&
      try(stmt.Condition.Bool["aws:MultiFactorAuthPresent"] == "true", false)
    ])
    error_message = "Security account cross-account trust must require MFA."
  }
}

# ------------------------------------------------------------------
# Developer policy must only read DynamoDB — not write it.
# This tests that "dynamodb" produces read-only actions.
run "developer_policy_allows_dynamodb_reads_only" {
  command = apply

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.developer_policy_json).Statement :
      stmt.Sid == "AllowReadOperations" &&
      contains(stmt.Action, "dynamodb:Get*")
    ])
    error_message = "Developer policy must allow dynamodb:Get* (read) for dynamodb service."
  }

  assert {
    condition = anytrue([
      for stmt in jsondecode(module.rbac.developer_policy_json).Statement :
      stmt.Sid == "DenyAllMutations" &&
      contains(stmt.Action, "*:Put*")
    ])
    error_message = "Developer policy must explicitly deny *:Put* write operations."
  }
}

# ------------------------------------------------------------------
# The rbac_summary output must accurately reflect the deployment.
run "rbac_summary_reflects_full_deployment" {
  command = apply

  assert {
    condition     = output.rbac_summary["role"] == "prod-payments-role"
    error_message = "rbac_summary.role must be 'prod-payments-role'."
  }

  assert {
    condition     = output.rbac_summary["boundary_enabled"] == true
    error_message = "rbac_summary.boundary_enabled must be true in this production scenario."
  }

  assert {
    condition     = output.rbac_summary["developer_group"] == "prod-payments-developers"
    error_message = "rbac_summary.developer_group must be 'prod-payments-developers'."
  }
}
