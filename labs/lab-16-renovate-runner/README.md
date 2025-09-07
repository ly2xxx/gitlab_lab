# Lab 16: Modern GitLab Renovate Runner - Pipeline-Based Dependency Automation

## Overview

This lab demonstrates the modern, GitLab-native approach to dependency automation using Renovate Runner - a **pipeline-based solution** that replaces traditional server-based dependency management tools. Unlike the old approach with Mend Renovate Community Edition containers, this method integrates directly into GitLab CI/CD pipelines for a lightweight, scalable, and maintainable solution.

## 🆚 Modern Approach vs Traditional

| Aspect | Traditional (Mend CE) | Modern (Renovate Runner) |
|--------|----------------------|--------------------------|
| **Architecture** | External server + webhooks | Native GitLab pipeline jobs |
| **Resource Usage** | Always-on container | On-demand execution |
| **Scalability** | Limited by server resources | Scales with GitLab runners |
| **Maintenance** | Server management required | Pipeline-based, self-contained |
| **Integration** | Webhook-driven | Native GitLab CI/CD |
| **Cost Model** | Fixed infrastructure | Pay-per-execution |

## Learning Objectives

By completing this lab, you will:

- ✅ Set up modern pipeline-based Renovate automation
- ✅ Configure GitLab bot account with proper permissions
- ✅ Implement scheduled pipeline-based dependency updates
- ✅ Create reusable CI/CD templates for other projects
- ✅ Configure advanced Renovate settings and presets
- ✅ Handle multi-language repositories effectively
- ✅ Set up security-focused dependency management
- ✅ Monitor and troubleshoot Renovate execution

## Prerequisites

- GitLab CE instance running (from Lab 00)
- Basic understanding of GitLab CI/CD pipelines
- Knowledge of dependency management concepts
- Understanding of YAML configuration

## Lab Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitLab Renovate Runner Architecture        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────── │
│  │ Scheduled       │    │ Renovate Runner │    │ Target         │
│  │ Pipeline        │    │ Project         │    │ Repositories   │
│  │                 │    │                 │    │                │
│  │ • Cron triggers │◄──►│ • Templates     │◄──►│ • Auto-        │
│  │ • Manual runs   │    │ • Config files  │    │   discovery    │
│  │ • Webhook calls │    │ • Scripts       │    │ • Per-repo     │
│  │                 │    │                 │    │   config       │
│  └─────────────────┘    └─────────────────┘    └─────────────── │
│           │                       │                      │      │
│           └───────────────────────┼──────────────────────┘      │
│                                   │                             │
│  ┌─────────────────────────────────▼─────────────────────────────│
│  │            GitLab Infrastructure                              │
│  │ • Pipeline scheduling  • Runner pool  • API access          │
│  │ • Merge request automation  • Repository management         │
│  └─────────────────────────────────────────────────────────────── │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
lab-16-renovate-runner/
├── README.md                           # This comprehensive tutorial
├── .gitlab-ci.yml                      # Main runner pipeline
├── renovate.json                       # Repository-specific config
├── config.js                           # Advanced JS configuration
├── templates/                          # Reusable CI templates
│   ├── renovate-runner.gitlab-ci.yml   # Basic template
│   ├── renovate-with-cache.yml         # Performance optimized
│   └── renovate-config-validator.yml   # Configuration validation
├── configs/                            # Configuration examples
│   └── presets/
│       ├── gitlab-optimized.json       # GitLab-specific settings
│       └── security-focused.json       # Security-first approach
├── sample-projects/                    # Test scenarios
│   ├── nodejs-app/                     # Node.js example
│   ├── python-app/                     # Python example
│   └── multi-lang/                     # Multi-language monorepo
├── scripts/                            # Automation helpers
│   ├── setup-bot-account.sh           # Bot account creation
│   ├── generate-token.sh              # PAT helper
│   ├── validate-setup.sh              # Setup validation
│   └── test-autodiscovery.sh          # Repository discovery test
└── docs/                              # Additional documentation
    ├── migration-from-mend-ce.md       # Migration guide
    ├── troubleshooting.md              # Common issues
    └── advanced-patterns.md            # Complex scenarios
```

---

## Part 1: Initial Setup

### Step 1: Create Renovate Runner Project

First, create a dedicated project for your Renovate Runner:

```bash
# Create new project in GitLab
# Name: renovate-runner
# Path: infrastructure/renovate-runner
# Visibility: Private (recommended)

# Clone locally
git clone http://localhost:8080/infrastructure/renovate-runner.git
cd renovate-runner

# Copy lab files
cp -r ../gitlab_lab101/labs/lab-16-renovate-runner/* .
```

### Step 2: Create GitLab Bot Account

1. **Access GitLab Admin Area**:
   ```bash
   # Ensure GitLab CE is running
   cd ../labs/lab-00-gitlab-self-host-docker
   docker-compose up -d
   
   # Open GitLab in browser
   open http://localhost:8080
   ```

2. **Create Bot User** (Admin Area → Users → New User):
   - **Username**: `renovate-bot`
   - **Name**: `Renovate Bot`
   - **Email**: `renovate-bot@example.local`
   - **Access Level**: Regular user
   - **External**: No

3. **Configure Bot Account**:
   - Login as `renovate-bot` 
   - Set permanent password
   - Optionally add SSH key

### Step 3: Generate Personal Access Token

1. **As renovate-bot user**: Profile → Preferences → Access Tokens
2. **Create token** with:
   - **Name**: `Renovate Runner Token`
   - **Scopes**: `api`, `read_user`, `write_repository`, `read_repository`
   - **Expiration**: Set appropriate date (1 year recommended)
   - **Role**: Developer (minimum)

3. **Save the token** - you'll need it in the next step

### Step 4: Configure CI/CD Variables

In your `renovate-runner` project, add these CI/CD variables:

**Project → Settings → CI/CD → Variables**:

```bash
# Required Variables
RENOVATE_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx  # GitLab PAT from Step 3
GITHUB_COM_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx  # GitHub token (optional but recommended)

# Optional Variables
RENOVATE_AUTODISCOVER_FILTER=group/*       # Repository filter
RENOVATE_DRY_RUN=                         # Leave empty for live mode
LOG_LEVEL=info                            # debug, info, warn, error

# Performance Settings
RENOVATE_PR_CONCURRENT_LIMIT=10           # Parallel MR limit
RENOVATE_BRANCH_CONCURRENT_LIMIT=10       # Parallel branch limit
```

---

## Part 2: Basic Runner Setup

### Step 1: Understand the Main Pipeline

Examine the main `.gitlab-ci.yml`:

```yaml
# Key features of the modern approach:
# 1. Scheduled execution (cron-based)
# 2. Resource groups for exclusive execution  
# 3. Artifact collection for logs and reports
# 4. Multiple job types (regular, dry-run, security-only)
# 5. Comprehensive workflow rules
```

### Step 2: Configure Pipeline Schedule

1. **Project → CI/CD → Schedules → New Schedule**:
   - **Description**: `Daily Renovate Run`
   - **Interval Pattern**: `0 2 * * *` (2 AM daily)
   - **Cron timezone**: `UTC`
   - **Target branch**: `main`
   - **Active**: ✅

2. **Optional - Additional Schedules**:
   - **Security Only**: `0 */6 * * *` (Every 6 hours)
     - Variable: `RENOVATE_SECURITY_ONLY=true`
   - **Weekend Major Updates**: `0 10 * * 0` (Sunday 10 AM)
     - Variable: `RENOVATE_EXTRA_FLAGS=--major-updates-only`

### Step 3: Test Manual Execution

```bash
# Commit and push the configuration
git add .
git commit -m "feat: initial renovate runner setup"
git push origin main

# Trigger manual pipeline
# Go to: Project → CI/CD → Pipelines → Run Pipeline
```

### Step 4: Monitor Execution

```bash
# View pipeline logs in GitLab UI or via CLI
# Check for successful bot authentication and repository discovery

# Expected output indicators:
# ✅ "Renovate version X.X.X"
# ✅ "GitLab API endpoint validated"
# ✅ "Discovered X repositories"
# ✅ "Processing repository: group/project"
```

---

## Part 3: Repository Integration

### Step 1: Add Bot to Target Repositories

For each repository you want Renovate to manage:

1. **Navigate to target repository**
2. **Project → Members → Invite members**
3. **Add `renovate-bot`** with:
   - **Role**: `Developer` (minimum)
   - **Access expiration**: None

### Step 2: Repository-Specific Configuration

Create `renovate.json` in each target repository:

**Basic Configuration**:
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "labels": ["renovate", "dependencies"],
  "schedule": ["after 10pm every weekday", "every weekend"],
  "platformAutomerge": true,
  "dependencyDashboard": true
}
```

**Using Presets**:
```json
{
  "extends": [
    "local>infrastructure/renovate-runner:configs/presets/gitlab-optimized"
  ]
}
```

### Step 3: Test Repository Discovery

```bash
# Run autodiscovery test
./scripts/test-autodiscovery.sh

# Or manually trigger with specific filter
# Pipeline → Run Pipeline with variables:
# RENOVATE_AUTODISCOVER_FILTER=your-group/*
# RENOVATE_DRY_RUN=full
```

---

## Part 4: Template Usage for Other Projects

### Step 1: Include Runner Template

In other projects' `.gitlab-ci.yml`:

```yaml
# Basic inclusion
include:
  - project: 'infrastructure/renovate-runner'
    file: '/templates/renovate-runner.gitlab-ci.yml'

# Add schedule for this project
renovate-run:
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
  variables:
    RENOVATE_EXTRA_FLAGS: "--include-forks=false"
```

### Step 2: Performance Template for Large Repos

```yaml
include:
  - project: 'infrastructure/renovate-runner'
    file: '/templates/renovate-with-cache.yml'

variables:
  RENOVATE_HIGH_PERFORMANCE: "true"
  RENOVATE_CACHE_WARM_FILTER: "large-org/*"
```

### Step 3: Configuration Validation Template

```yaml
include:
  - project: 'infrastructure/renovate-runner' 
    file: '/templates/renovate-config-validator.yml'

# Automatically validates renovate.json on changes
```

---

## Part 5: Advanced Configuration Patterns

### Step 1: JavaScript Configuration (config.js)

For dynamic configuration, use `config.js`:

```javascript
// Environment-based settings
const isProduction = process.env.NODE_ENV === 'production';

module.exports = {
  platform: 'gitlab',
  autodiscover: true,
  autodiscoverFilter: process.env.RENOVATE_AUTODISCOVER_FILTER || '*/*',
  
  // Dynamic settings based on environment
  dryRun: isProduction ? null : 'full',
  prConcurrentLimit: isProduction ? 20 : 5,
  
  // Custom package rules based on detected technologies
  packageRules: generatePackageRules()
};
```

### Step 2: Security-Focused Preset

Use the security preset for critical repositories:

```json
{
  "extends": [
    "local>infrastructure/renovate-runner:configs/presets/security-focused"
  ],
  "vulnerabilityAlerts": {
    "assignees": ["@your-security-team"]
  }
}
```

### Step 3: Multi-Language Configuration

For complex monorepos:

```json
{
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "matchFiles": ["frontend/package.json"],
      "labels": ["frontend"],
      "assignees": ["@frontend-team"]
    },
    {
      "matchFiles": ["requirements*.txt"],
      "labels": ["backend", "python"],
      "assignees": ["@backend-team"]
    }
  ]
}
```

---

## Part 6: Sample Project Testing

### Step 1: Test Node.js Project

```bash
# Navigate to Node.js sample
cd sample-projects/nodejs-app

# Review configuration
cat renovate.json

# Push to GitLab to test
git init
git remote add origin http://localhost:8080/samples/nodejs-app.git
git add .
git commit -m "feat: initial nodejs sample for renovate testing"
git push -u origin main
```

### Step 2: Test Python Project

```bash
# Navigate to Python sample
cd ../python-app

# Note the pinning strategy for Python dependencies
cat renovate.json

# Push to test
git init
git remote add origin http://localhost:8080/samples/python-app.git  
git add .
git commit -m "feat: initial python sample for renovate testing"
git push -u origin main
```

### Step 3: Test Multi-Language Project

```bash
# Navigate to multi-language sample
cd ../multi-lang

# Review complex configuration
cat renovate.json

# Push to test
git init
git remote add origin http://localhost:8080/samples/multi-lang-app.git
git add .
git commit -m "feat: initial multi-language sample for renovate testing"
git push -u origin main
```

---

## Part 7: Monitoring and Troubleshooting

### Step 1: Pipeline Monitoring

Monitor Renovate execution through:

1. **GitLab Pipeline UI**:
   - Project → CI/CD → Pipelines
   - View job logs and artifacts

2. **Generated Reports**:
   - `renovate-log.ndjson` - Detailed execution logs
   - `renovate-report.md` - Summary report  
   - `renovate-summary.json` - Execution metadata

### Step 2: Dependency Dashboard

Each repository gets a "Dependency Dashboard" issue:

- **Location**: Repository Issues
- **Title**: 🔧 Dependency Dashboard
- **Content**: Status of all dependency updates
- **Updates**: Real-time status of MRs

### Step 3: Common Issues and Solutions

**Issue**: Bot authentication fails
```bash
# Check token permissions and expiration
curl -H "Private-Token: $RENOVATE_TOKEN" \
     http://localhost:8080/api/v4/user
```

**Issue**: No repositories discovered
```bash
# Check autodiscovery filter
echo "Filter: $RENOVATE_AUTODISCOVER_FILTER"
# Verify bot has access to repositories
```

**Issue**: MRs not created
```bash
# Check bot repository permissions (Developer minimum)
# Verify renovate.json configuration validity
npx renovate-config-validator renovate.json
```

### Step 4: Performance Monitoring

```bash
# Monitor cache effectiveness
du -sh renovate/cache/

# Check concurrent limits
grep -i "concurrent" renovate-log.ndjson

# Review execution time
grep -i "duration" renovate-report.md
```

---

## Part 8: Advanced Patterns and Customization

### Step 1: Custom Regex Managers

Handle non-standard dependency formats:

```json
{
  "regexManagers": [
    {
      "fileMatch": ["^scripts/install\\.sh$"],
      "matchStrings": [
        "KUBECTL_VERSION=(?<currentValue>[0-9.]+)"
      ],
      "depNameTemplate": "kubernetes/kubectl",
      "datasourceTemplate": "github-releases"
    }
  ]
}
```

### Step 2: Workflow Integration

Integrate with existing workflows:

```yaml
# .gitlab-ci.yml
renovate-approval-workflow:
  script:
    - |
      if [[ "$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME" =~ ^renovate/ ]]; then
        # Auto-approve minor/patch updates
        if [[ "$CI_MERGE_REQUEST_TITLE" =~ (patch|minor) ]]; then
          # Call approval API
          echo "Auto-approving minor/patch update"
        fi
      fi
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

### Step 3: Security Integration

Integrate with security scanning:

```json
{
  "vulnerabilityAlerts": {
    "enabled": true,
    "schedule": ["at any time"]
  },
  "osvVulnerabilityAlerts": true,
  "packageRules": [
    {
      "matchPackagePatterns": ["*security*"],
      "schedule": ["at any time"],
      "assignees": ["@security-team"]
    }
  ]
}
```

---

## Part 9: Migration from Mend CE

### For Users Migrating from Lab 16 (Mend CE)

If you previously used the Mend Renovate Community Edition approach:

1. **Stop Mend CE containers**:
   ```bash
   cd ../lab-16-mend-renovate
   docker-compose down -v
   ```

2. **Migrate configuration**:
   ```bash
   # Convert Mend CE config to Renovate Runner format
   ./scripts/migrate-from-mend-ce.sh
   ```

3. **Update repository configurations**:
   - Remove webhook URLs
   - Update renovate.json to use GitLab-specific settings
   - Migrate from server-based to pipeline-based triggers

See `docs/migration-from-mend-ce.md` for detailed migration steps.

---

## Part 10: Production Deployment

### Step 1: Production Checklist

Before deploying to production:

- ✅ Bot account properly configured
- ✅ All target repositories have bot as member
- ✅ Pipeline schedules configured
- ✅ Monitoring and alerting setup
- ✅ Backup strategy for configurations
- ✅ Team training completed

### Step 2: Scaling Considerations

For large-scale deployments:

```yaml
# Use performance template
include:
  - project: 'infrastructure/renovate-runner'
    file: '/templates/renovate-with-cache.yml'

variables:
  # Increase concurrency limits
  RENOVATE_PR_CONCURRENT_LIMIT: 50
  RENOVATE_BRANCH_CONCURRENT_LIMIT: 50
  
  # Enable high-performance mode
  RENOVATE_HIGH_PERFORMANCE: "true"
```

### Step 3: Maintenance Schedule

Regular maintenance tasks:
- **Weekly**: Review failed pipelines and error logs
- **Monthly**: Update Renovate runner image version
- **Quarterly**: Review and update configuration presets
- **Annually**: Rotate bot account tokens

---

## Cleanup

```bash
# Stop any running test containers
docker-compose down -v

# Clean up test repositories (optional)
# Remove sample projects from GitLab if no longer needed

# Keep the renovate-runner project for ongoing use
```

---

## Summary

✅ **Accomplished in this lab**:

1. **Modern Architecture**: Implemented pipeline-based Renovate automation vs traditional server approach
2. **GitLab Integration**: Native CI/CD integration with scheduled pipelines and proper workflow rules
3. **Scalable Design**: On-demand execution model that scales with GitLab infrastructure
4. **Template System**: Reusable CI/CD templates for consistent deployment across projects
5. **Advanced Configuration**: JavaScript-based dynamic configuration and security-focused presets
6. **Multi-Language Support**: Comprehensive examples for Node.js, Python, and multi-language repositories
7. **Production-Ready**: Performance optimization, monitoring, and troubleshooting capabilities

## Key Advantages of Modern Approach

- **💰 Cost Effective**: Pay-per-execution vs always-on infrastructure
- **🔧 Low Maintenance**: No server management or webhook configuration
- **📈 Scalable**: Leverages existing GitLab runner infrastructure  
- **🔒 Secure**: Native GitLab permissions and API integration
- **⚡ Performance**: Advanced caching and concurrent processing
- **🎯 Focused**: Pipeline-based approach aligns with GitLab workflows

## Next Steps

- **Advanced Patterns**: Explore complex monorepo and multi-project scenarios
- **Custom Integrations**: Build custom approval workflows and notification systems
- **Enterprise Features**: Implement organization-wide policies and governance
- **Monitoring Enhancement**: Add comprehensive observability and alerting

## Additional Resources

- [Official Renovate Runner Repository](https://gitlab.com/renovate-bot/renovate-runner)
- [Renovate Documentation](https://docs.renovatebot.com/)
- [GitLab CI/CD Pipeline Documentation](https://docs.gitlab.com/ee/ci/)
- [Renovate Configuration Options](https://docs.renovatebot.com/configuration-options/)

---

**🎉 Congratulations!** You've successfully implemented modern, GitLab-native dependency automation that represents the current best practices for 2025 and beyond.