# Lab 23: Terraform Declarative Testing with `.tftest.hcl` and Mock Providers

**Time to complete: ~75 minutes | Difficulty: Intermediate-Advanced**

---

## What You'll Learn

By completing this lab you will understand:

- **Terraform test framework** (v1.7+) — `terraform test`, `run` blocks, `assert` blocks
- **`.tftest.hcl` file syntax** — variables, multiple run blocks, `command = plan | apply`
- **`mock_provider` blocks** — test infrastructure logic without real cloud credentials
- **RBAC on AWS IAM** — permission boundaries, least-privilege policies, separation of duties
- **GitLab CI/CD integration** — running `terraform test` in pipelines with JUnit reports
- **Test design patterns** — unit vs integration tests, positive and negative assertions

---

## Prerequisites

| Requirement | Version / Notes |
|-------------|-----------------|
| Terraform | `>= 1.7.0` (introduces `mock_provider`) |
| GitLab Runner | Any executor with Docker support |
| AWS credentials | **NOT required** — all tests use `mock_provider` |
| Git | Any recent version |

Install Terraform locally:
```bash
# macOS
brew tap hashicorp/tap && brew install hashicorp/tap/terraform

# Linux (any distro)
curl -fsSL https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip \
  | funzip > /usr/local/bin/terraform && chmod +x /usr/local/bin/terraform

terraform version   # should print >= 1.7.0
```

---

## Background: Why Test Terraform?

Infrastructure bugs are expensive. A misconfigured IAM policy can:

- Grant unintended access (security breach)
- Deny intended access (production outage)
- Fail silently until the specific API call is made in prod

The `terraform test` framework (GA in Terraform 1.6, `mock_provider` in 1.7) lets you validate your configuration **before** touching real infrastructure. Tests are HCL files — same language as your config — so the learning curve is low.

### Test Types

| Type | `command` | Provider | Purpose |
|------|-----------|----------|---------|
| **Unit** | `plan` or `apply` | `mock_provider` | Validate logic and naming — fast, no creds |
| **Integration** | `apply` | `mock_provider` | Validate whole system composes correctly |
| **Live** (advanced) | `apply` | real provider | Validate against a real sandbox account |

This lab covers unit and integration tests, both using `mock_provider`.

---

## RBAC Concepts in This Lab

The module under test implements a Zero-Trust RBAC model on AWS IAM:

```
┌──────────────────────────────────────────────────────────────────┐
│  Zero-Trust RBAC Layers                                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │  Permission Boundary (HARD CAP)                         │     │
│  │  "No matter what policies are attached, the role        │     │
│  │   can never exceed these permissions."                  │     │
│  │  → Blocks: iam:CreateRole, iam:AttachRolePolicy, etc.   │     │
│  └─────────────────────────────────────────────────────────┘     │
│                                                                  │
│  ┌───────────────────┐   ┌──────────────────────────────────┐    │
│  │  Application Role │   │  Human Groups                    │    │
│  │  (service identity│   │                                  │    │
│  │   for EC2/Lambda) │   │  developers  →  read-only policy │    │
│  │                   │   │  admins      →  managed policies  │    │
│  │  + least-privilege│   │                                  │    │
│  │    app policy     │   │  Explicit Deny on all mutations  │    │
│  └───────────────────┘   └──────────────────────────────────┘    │
│                                                                  │
│  Cross-account assumption: MFA + ExternalId (prevents           │
│  confused-deputy attacks from partner accounts)                 │
└──────────────────────────────────────────────────────────────────┘
```

### Key RBAC Principles Demonstrated

| Principle | Implementation |
|-----------|----------------|
| **Least privilege** | `app_permissions` variable: only grant what the service needs |
| **Separation of duties** | Developers and admins are distinct groups with different policies |
| **Deny by default** | No `app_permissions` → policy contains `DefaultDenyAll` |
| **Defence in depth** | Explicit `Deny` in developer policy even where `Allow` is absent |
| **Privilege escalation prevention** | Permission boundary blocks all `iam:Create*` / `iam:Attach*` |
| **Zero trust cross-account** | MFA + ExternalId required for every cross-account assumption |

---

## Project Structure

```
lab-23-terraform-testing/
├── .gitlab-ci.yml                    # 5-stage CI/CD pipeline
├── README.md                         # This file
│
├── versions.tf                       # Provider requirements (>= 1.7.0)
├── main.tf                           # Root: calls modules/rbac
├── variables.tf                      # Input variables with validation
├── outputs.tf                        # Root outputs (role, groups, summary)
│
├── modules/
│   └── rbac/
│       ├── main.tf                   # IAM role, policies, groups
│       ├── variables.tf
│       └── outputs.tf                # Exposes policy JSON for test assertions
│
├── tests/
│   ├── unit/
│   │   ├── naming_convention.tftest.hcl    # Resource naming patterns
│   │   ├── permission_boundary.tftest.hcl  # Boundary on/off + policy content
│   │   └── rbac_separation.tftest.hcl      # Group isolation + policy logic
│   └── integration/
│       └── full_rbac_deployment.tftest.hcl # End-to-end payments service scenario
│
└── scripts/
    └── tf-test-to-junit.py           # Converts terraform test -json → JUnit XML
```

---

## Part 1 – Explore the Module (10 min)

### Step 1: Review the RBAC module

```bash
cd labs/lab-23-terraform-testing

# Read the module's main resource definitions
cat modules/rbac/main.tf
```

Notice the five resources created and why each exists:

1. `aws_iam_policy.permission_boundary` — the "ceiling" on maximum permissions
2. `aws_iam_role.application_role` — service identity (assumed by EC2/Lambda/ECS)
3. `aws_iam_policy.application_policy` — the actual app permissions (least privilege)
4. `aws_iam_group.developers` + `aws_iam_policy.developer_readonly` — read-only humans
5. `aws_iam_group.admins` — elevated human access via managed policies

### Step 2: Initialise Terraform

```bash
terraform init -backend=false
```

This downloads the AWS provider (~60 MB) into `.terraform/`. The provider is needed
even with `mock_provider` because Terraform uses it for schema validation.

### Step 3: Validate the configuration

```bash
terraform validate
terraform fmt -check -recursive
```

---

## Part 2 – Understand `.tftest.hcl` Syntax (15 min)

### Anatomy of a test file

```hcl
# 1. Mock the provider — replaces real API calls with in-memory fakes.
#    Terraform still uses the provider's schema for type-checking.
mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = {
      # Set computed attributes that would normally come from AWS.
      arn       = "arn:aws:iam::111122223333:role/mock-role"
      unique_id = "AROAEXAMPLE00TEST"
    }
  }
}

# 2. File-level variables — shared by all run blocks below.
variables {
  environment      = "staging"
  application_name = "webapp"
}

# 3. A run block = one test case.
run "role_name_follows_convention" {
  # command = plan  → validates planned changes, no state written
  # command = apply → mock-applies resources, state written to temp workspace
  command = plan

  # Per-run variable overrides (merged with file-level variables)
  variables {
    environment = "prod"
  }

  # Assert: any valid HCL expression that evaluates to bool.
  # Reference module outputs, variables, or locals.
  assert {
    condition     = module.rbac.role_name == "prod-webapp-role"
    error_message = "Role name wrong: ${module.rbac.role_name}"
  }
}
```

### Key syntax rules

| Syntax element | Purpose |
|----------------|---------|
| `mock_provider "aws" {}` | Replace real AWS provider with an in-memory mock |
| `mock_resource "type" { defaults = {} }` | Set return values for computed attributes |
| `variables {}` (file level) | Shared variable values for the whole file |
| `run "name" {}` | A single named test case |
| `command = plan` | Plan only — fast, no state changes |
| `command = apply` | Mock-apply — needed for computed attribute assertions |
| `assert { condition = ... }` | Boolean expression that must be `true` |
| `jsondecode(...)` | Parse IAM policy JSON for deep inspection |

### `command = plan` vs `command = apply`

```
plan  → Tests configuration logic (names, tags, conditional resources)
        Fast. Does NOT write state. Good for: naming, variable validation.

apply → Mock-creates resources and exposes computed attributes.
        Slightly slower. Good for: policy JSON content, ARN references.
```

---

## Part 3 – Run the Unit Tests Locally (20 min)

### Step 1: Run all tests

```bash
terraform test -verbose
```

You should see output like:

```
tests/unit/naming_convention.tftest.hcl... in progress
  run "application_role_name_follows_convention"... pass
  run "developer_group_name_follows_convention"... pass
  run "admin_group_name_follows_convention"... pass
  run "naming_convention_holds_in_prod"... pass
  run "rbac_summary_output_has_expected_keys"... pass
tests/unit/naming_convention.tftest.hcl... tearing down
tests/unit/naming_convention.tftest.hcl... pass

tests/unit/permission_boundary.tftest.hcl... in progress
  ...
```

### Step 2: Run a specific test file

```bash
terraform test -filter=tests/unit/permission_boundary.tftest.hcl -verbose
```

### Step 3: Run with JSON output (for CI/CD)

```bash
terraform test -json | tee test-results.jsonl
# Convert to JUnit XML for GitLab test reporting
python3 scripts/tf-test-to-junit.py test-results.jsonl > test-results.xml
```

### Step 4: Intentionally break a test (learning exercise)

Open `modules/rbac/main.tf` and change the role name:

```hcl
# Change this:
name = "${local.name_prefix}-role"
# To this:
name = "${var.application_name}-${var.environment}"   # wrong order
```

Re-run the tests:
```bash
terraform test -filter=tests/unit/naming_convention.tftest.hcl -verbose
```

You'll see the assertion fail with a descriptive error message. Revert the change.

---

## Part 4 – Understand the Test Design Patterns (10 min)

### Pattern 1: Plan-time naming assertion

Tests that resource names follow a convention without applying anything:

```hcl
# From tests/unit/naming_convention.tftest.hcl
run "application_role_name_follows_convention" {
  command = plan

  assert {
    condition     = module.rbac.role_name == "staging-webapp-role"
    error_message = "Role name must follow '{env}-{app}-role'. Got: ${module.rbac.role_name}"
  }
}
```

### Pattern 2: Policy JSON deep inspection

Parses IAM policy JSON and checks specific statement content:

```hcl
# From tests/unit/rbac_separation.tftest.hcl
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
```

### Pattern 3: Negative test (disabled feature)

Tests that a feature is correctly absent when turned off:

```hcl
run "boundary_is_null_when_disabled" {
  command = apply

  variables {
    enable_permission_boundary = false
  }

  assert {
    condition     = module.rbac.permission_boundary_arn == null
    error_message = "Permission boundary ARN must be null when disabled."
  }
}
```

### Pattern 4: Cross-run variable override

The same test file can cover multiple environments:

```hcl
variables {
  environment = "staging"   # default
}

run "naming_in_staging" {
  command = plan
  # uses file-level environment = "staging"
  assert { condition = module.rbac.role_name == "staging-webapp-role" ... }
}

run "naming_in_prod" {
  command = plan
  variables { environment = "prod" }   # override just for this run
  assert { condition = module.rbac.role_name == "prod-webapp-role" ... }
}
```

---

## Part 5 – GitLab CI/CD Pipeline (15 min)

### Pipeline overview

```
validate:fmt    ──────────────────────────────────── (all branches)
validate:syntax ──────────────────────────────────── (all branches)
                     ↓
security:tfsec  ──────────────────────────────────── (parallel, all branches)
                     ↓
test:unit:naming ─┐
test:unit:boundary├────────────────────────────────── (all branches)
test:unit:rbac ───┘
                     ↓
test:integ:full ─────────────────────────────────── (main: auto | MR: manual)
                     ↓
report:summary  ──────────────────────────────────── (always, even on failure)
```

### Step 1: Copy the pipeline to your GitLab project

```bash
# Option A: copy the file to your project root
cp labs/lab-23-terraform-testing/.gitlab-ci.yml .gitlab-ci.yml

# Option B: use GitLab's include directive in your root .gitlab-ci.yml
# include:
#   - local: labs/lab-23-terraform-testing/.gitlab-ci.yml
```

### Step 2: Push and watch the pipeline

```bash
git add .
git commit -m "lab-23: add terraform testing lab"
git push
```

Navigate to **CI/CD → Pipelines** in GitLab to see the five stages run.

### Step 3: View test results in GitLab

GitLab natively displays JUnit test reports in the merge request widget:

1. Open a merge request
2. Scroll to the test summary widget
3. Click individual test names to see pass/fail details and error messages

The pipeline uploads `.xml` files via:
```yaml
artifacts:
  reports:
    junit: ${LAB_DIR}/test-unit-naming.xml
```

### Step 4: Run the integration test manually (on feature branches)

On feature branches the integration test is set to `when: manual`. Click the
play button next to `test:integ:full-rbac` in the pipeline graph.

---

## Part 6 – Advanced Exercises

### Exercise A: Add a new validation rule

The `variables.tf` file already has two validations. Add a third that prevents
the application name from containing the environment name (avoids duplicates
like `prod-prod-app-role`):

```hcl
# In variables.tf
validation {
  condition     = !strcontains(var.application_name, var.environment)
  error_message = "application_name must not contain the environment name."
}
```

Write a test that verifies this validation fires:

```hcl
# In a new tests/unit/variable_validation.tftest.hcl
run "reject_app_name_containing_env" {
  command = plan

  variables {
    environment      = "prod"
    application_name = "prod-payments"  # invalid
  }

  expect_failures = [var.application_name]
}
```

### Exercise B: Add a `dev` exception for permission boundaries

Modify the module to make `enable_permission_boundary` default to `false` only
when `environment == "dev"`. Write a test that captures this behaviour:

```hcl
run "dev_does_not_require_boundary" {
  command = plan
  variables { environment = "dev" }
  # assert boundary is optional in dev
}
```

### Exercise C: Extend to Kubernetes RBAC

The RBAC pattern translates directly to Kubernetes. Add a second module
`modules/k8s-rbac/` that creates:

- `kubernetes_role` with read-only verbs
- `kubernetes_role_binding` linking a ServiceAccount
- `kubernetes_cluster_role` for admin access

Write `.tftest.hcl` files that mock the `kubernetes` provider and validate
the same separation-of-duties principles.

---

## Troubleshooting

### `Error: Required plugins are not installed`

```bash
terraform init -backend=false
```

### `Error: Unsupported block type "mock_provider"`

You are using Terraform < 1.7.0. Upgrade:
```bash
terraform version
# Install 1.7.5 or newer
```

### Test assertions fail with "value is null"

In `command = plan` mode, some computed values may not be available.
Switch to `command = apply` which mock-applies the resources and
resolves all computed attributes using mock defaults.

### tfsec findings block the pipeline

By default `tfsec` in this pipeline uses `--soft-fail`. Remove that flag
to make security findings block merges:
```yaml
- tfsec ${LAB_DIR} --format default   # remove --soft-fail
```

### Provider download fails in CI

Add a GitLab CI/CD variable `TF_PLUGIN_CACHE_DIR` pointing to a persistent
cache volume, or use a `hashicorp/terraform` Docker image that pre-includes
the provider via a custom Dockerfile.

---

## Validation Checklist

Work through these before moving to the next lab:

- [ ] `terraform init -backend=false` completes without errors
- [ ] `terraform validate` passes
- [ ] `terraform fmt -check -recursive` passes (no unformatted files)
- [ ] `terraform test -verbose` — all tests pass (green)
- [ ] Intentionally broke a test and saw a descriptive failure message
- [ ] Understood the difference between `command = plan` and `command = apply`
- [ ] Understood how `jsondecode()` enables deep policy assertions
- [ ] Pushed to GitLab and watched the full 5-stage pipeline run
- [ ] Viewed JUnit test report in a merge request

---

## Key Concepts Recap

| Concept | What it does |
|---------|-------------|
| `terraform test` | Discovers and runs all `.tftest.hcl` files |
| `mock_provider "aws"` | Replaces real AWS API calls with in-memory fakes |
| `mock_resource "type" { defaults }` | Provides values for computed attributes in tests |
| `run "name" { command = plan }` | Validates planned changes without touching state |
| `run "name" { command = apply }` | Mock-applies resources, enables computed-attr checks |
| `assert { condition = ... }` | HCL boolean expression that must be true |
| `-filter=path/to/file.tftest.hcl` | Run a single test file |
| `jsondecode(policy_json).Statement` | Traverse IAM policy JSON in assertions |
| Permission boundary | IAM hard cap — maximum permissions a role can ever have |
| `ExternalId` condition | Prevents confused-deputy cross-account attacks |

---

## Next Steps

- **Lab 24** (coming soon): Terraform remote state and workspaces in GitLab CI
- **Further reading:**
  - [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
  - [Mock Providers](https://developer.hashicorp.com/terraform/language/tests/mocking)
  - [AWS IAM Permission Boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)
  - [Confused Deputy Problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html)
