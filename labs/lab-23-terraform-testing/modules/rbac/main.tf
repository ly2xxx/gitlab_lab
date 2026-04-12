# ============================================================
# RBAC Module - AWS IAM Role-Based Access Control
#
# Implements the Zero-Trust RBAC model with:
#   1. Permission Boundary  - hard cap on maximum permissions
#   2. Application Role     - service identity (EC2/Lambda/ECS)
#   3. Application Policy   - least-privilege permissions
#   4. Developer Group      - human read-only access
#   5. Admin Group          - elevated access with guardrails
# ============================================================

locals {
  name_prefix = "${var.environment}-${var.application_name}"

  common_tags = {
    Environment = var.environment
    Application = var.application_name
    ManagedBy   = "terraform"
    Team        = "platform"
  }

  # Derive read actions for every requested service
  developer_read_actions = flatten([
    for svc in var.developer_readonly_services : [
      "${svc}:Get*",
      "${svc}:List*",
      "${svc}:Describe*",
    ]
  ])
}

# ============================================================
# 1. Permission Boundary
#    Defines the MAXIMUM permissions the application role
#    can ever hold, regardless of what policies are attached.
#    This is the "guardrail" layer in a Zero-Trust model.
# ============================================================
resource "aws_iam_policy" "permission_boundary" {
  count = var.enable_permission_boundary ? 1 : 0

  name        = "${local.name_prefix}-boundary"
  description = "Permission boundary for ${var.application_name}/${var.environment}: caps max IAM scope"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedServices"
        Effect = "Allow"
        Action = [
          "s3:*",
          "dynamodb:*",
          "sqs:*",
          "sns:*",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "secretsmanager:GetSecretValue",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
        ]
        Resource = "*"
      },
      {
        # Explicitly block IAM privilege-escalation paths.
        # Even if a misconfigured policy grants iam:CreateRole,
        # this boundary prevents it from taking effect.
        Sid    = "DenyPrivilegeEscalation"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:UpdateAssumeRolePolicy",
          "iam:PassRole",
          "organizations:*",
          "account:*",
        ]
        Resource = "*"
      },
    ]
  })

  tags = local.common_tags
}

# ============================================================
# 2. Application Service Role
#    Assumed by AWS services (EC2, Lambda, ECS tasks).
#    Cross-account assumption requires MFA — no exceptions.
# ============================================================
resource "aws_iam_role" "application_role" {
  name                 = "${local.name_prefix}-role"
  description          = "Service identity for ${var.application_name} in ${var.environment}"
  permissions_boundary = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowAWSServices"
          Effect = "Allow"
          Principal = {
            Service = [
              "ec2.amazonaws.com",
              "lambda.amazonaws.com",
              "ecs-tasks.amazonaws.com",
            ]
          }
          Action = "sts:AssumeRole"
        }
      ],
      length(var.trusted_account_ids) > 0 ? [
        {
          Sid    = "AllowCrossAccountWithMFA"
          Effect = "Allow"
          Principal = {
            AWS = [for id in var.trusted_account_ids : "arn:aws:iam::${id}:root"]
          }
          Action = "sts:AssumeRole"
          Condition = {
            Bool         = { "aws:MultiFactorAuthPresent" = "true" }
            StringEquals = { "sts:ExternalId" = "${var.environment}-${var.application_name}" }
          }
        }
      ] : []
    )
  })

  tags = local.common_tags
}

# ============================================================
# 3. Application Policy (Least Privilege)
#    Contains exactly the permissions the app needs.
#    Bounded above by the permission boundary.
# ============================================================
resource "aws_iam_policy" "application_policy" {
  name        = "${local.name_prefix}-policy"
  description = "Least-privilege policy for ${var.application_name} in ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = length(var.app_permissions) > 0 ? [
      for perm in var.app_permissions : {
        Sid      = perm.sid
        Effect   = perm.effect
        Action   = perm.actions
        Resource = perm.resources
      }
      ] : [
      {
        # Default deny-all — forces explicit permission grants
        Sid      = "DefaultDenyAll"
        Effect   = "Deny"
        Action   = ["*"]
        Resource = ["*"]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "application_policy" {
  role       = aws_iam_role.application_role.name
  policy_arn = aws_iam_policy.application_policy.arn
}

# ============================================================
# 4. Developer Group (Read-Only)
#    Humans who need visibility but must not modify state.
#    Explicit Deny on all write verbs — belt AND braces.
# ============================================================
resource "aws_iam_group" "developers" {
  name = "${local.name_prefix}-developers"
  path = "/rbac/${var.environment}/"
}

resource "aws_iam_policy" "developer_readonly" {
  name        = "${local.name_prefix}-developer-readonly"
  description = "Read-only access for developers: ${var.application_name}/${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowReadOperations"
        Effect   = "Allow"
        Action   = local.developer_read_actions
        Resource = ["*"]
      },
      {
        Sid    = "DenyAllMutations"
        Effect = "Deny"
        Action = [
          "*:Create*",
          "*:Delete*",
          "*:Update*",
          "*:Put*",
          "*:Modify*",
          "*:Terminate*",
          "*:Stop*",
          "*:Start*",
        ]
        Resource = ["*"]
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_group_policy_attachment" "developer_readonly" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.developer_readonly.arn
}

# ============================================================
# 5. Admin Group (Elevated Access)
#    Attaches AWS managed policies; additional scoping via
#    the separate permission boundary on the role.
# ============================================================
resource "aws_iam_group" "admins" {
  name = "${local.name_prefix}-admins"
  path = "/rbac/${var.environment}/"
}

resource "aws_iam_group_policy_attachment" "admin_policies" {
  for_each = toset(var.admin_managed_policy_arns)

  group      = aws_iam_group.admins.name
  policy_arn = each.value
}
