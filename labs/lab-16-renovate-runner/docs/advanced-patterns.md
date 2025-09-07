# Advanced Renovate Runner Patterns

This guide covers advanced configuration patterns and complex scenarios for GitLab Renovate Runner.

## Table of Contents

- [Multi-Environment Management](#multi-environment-management)
- [Monorepo and Workspace Handling](#monorepo-and-workspace-handling)
- [Custom Approval Workflows](#custom-approval-workflows)
- [Security and Compliance Integration](#security-and-compliance-integration)
- [Performance Optimization](#performance-optimization)
- [Custom Package Managers](#custom-package-managers)
- [Advanced Scheduling Patterns](#advanced-scheduling-patterns)
- [Integration with External Systems](#integration-with-external-systems)

## Multi-Environment Management

### Environment-Specific Configuration

**config.js** - Dynamic environment handling:

```javascript
const environment = process.env.NODE_ENV || 'development';
const isProduction = environment === 'production';

module.exports = {
  platform: 'gitlab',
  autodiscover: true,
  
  // Environment-specific repository filtering
  autodiscoverFilter: getEnvironmentFilter(environment),
  
  // Different update strategies per environment
  packageRules: [
    {
      description: "Production: Conservative updates only",
      matchFiles: ["**/production/**", "**/prod/**"],
      matchUpdateTypes: ["patch"],
      schedule: ["every weekend"],
      automerge: false,
      assignees: ["@production-team"],
      labels: ["production", "conservative"]
    },
    {
      description: "Staging: Allow minor updates",
      matchFiles: ["**/staging/**", "**/stage/**"],
      matchUpdateTypes: ["minor", "patch"], 
      schedule: ["after 10pm every weekday"],
      automerge: true,
      labels: ["staging", "automated"]
    },
    {
      description: "Development: Aggressive updates",
      matchFiles: ["**/development/**", "**/dev/**"],
      matchUpdateTypes: ["major", "minor", "patch"],
      schedule: ["at any time"],
      automerge: true,
      labels: ["development", "bleeding-edge"]
    }
  ],
  
  // Environment-specific settings
  prConcurrentLimit: isProduction ? 5 : 20,
  branchConcurrentLimit: isProduction ? 5 : 20,
  prHourlyLimit: isProduction ? 2 : 10
};

function getEnvironmentFilter(env) {
  const filters = {
    'production': 'production/*',
    'staging': '{staging/*,stage/*}',
    'development': '{dev/*,development/*,feature/*}',
    'all': '*/*'
  };
  return filters[env] || filters.development;
}
```

### Environment Pipeline Matrix

**.gitlab-ci.yml** - Multi-environment execution:

```yaml
variables:
  CI_RENOVATE_IMAGE: ghcr.io/renovatebot/renovate:41

.renovate-base: &renovate-base
  image: ${CI_RENOVATE_IMAGE}
  cache:
    key: ${CI_COMMIT_REF_SLUG}-renovate-${ENVIRONMENT}
    paths:
      - renovate/cache/renovate/repository/

# Production environment - conservative updates
renovate-production:
  <<: *renovate-base
  stage: renovate
  variables:
    NODE_ENV: production
    ENVIRONMENT: production
    RENOVATE_AUTODISCOVER_FILTER: "production/*"
  script:
    - renovate --schedule="every weekend" $RENOVATE_EXTRA_FLAGS
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $SCHEDULE_TYPE == "production"'
  resource_group: renovate-production

# Staging environment - balanced approach  
renovate-staging:
  <<: *renovate-base
  stage: renovate
  variables:
    NODE_ENV: staging
    ENVIRONMENT: staging
    RENOVATE_AUTODISCOVER_FILTER: "{staging/*,stage/*}"
  script:
    - renovate $RENOVATE_EXTRA_FLAGS
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $SCHEDULE_TYPE == "staging"'
  resource_group: renovate-staging

# Development environment - aggressive updates
renovate-development:
  <<: *renovate-base
  stage: renovate
  variables:
    NODE_ENV: development
    ENVIRONMENT: development
    RENOVATE_AUTODISCOVER_FILTER: "{dev/*,development/*}"
  script:
    - renovate --schedule="at any time" $RENOVATE_EXTRA_FLAGS
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule" && $SCHEDULE_TYPE == "development"'
  resource_group: renovate-development
```

## Monorepo and Workspace Handling

### Complex Monorepo Configuration

**renovate.json** - Advanced monorepo patterns:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended", "group:monorepos"],
  "packageRules": [
    {
      "description": "Frontend workspace packages",
      "matchFiles": ["packages/frontend/*/package.json"],
      "groupName": "Frontend workspace",
      "labels": ["frontend", "workspace"],
      "assignees": ["@frontend-team"],
      "reviewers": ["@frontend-team"],
      "schedule": ["after 6pm every weekday"]
    },
    {
      "description": "Backend workspace packages", 
      "matchFiles": ["packages/backend/*/package.json"],
      "groupName": "Backend workspace",
      "labels": ["backend", "workspace"],
      "assignees": ["@backend-team"],
      "reviewers": ["@backend-team"]
    },
    {
      "description": "Shared libraries - require cross-team review",
      "matchFiles": ["packages/shared/*/package.json"],
      "groupName": "Shared libraries",
      "labels": ["shared", "cross-team"],
      "assignees": ["@tech-leads"],
      "reviewers": ["@frontend-team", "@backend-team"],
      "automerge": false
    },
    {
      "description": "Root workspace dependencies",
      "matchFiles": ["package.json"],
      "matchDepTypes": ["devDependencies"],
      "labels": ["build-tools", "root"],
      "groupName": "Build and tooling",
      "automerge": true
    },
    {
      "description": "Workspace protocol dependencies",
      "matchPackagePatterns": ["^workspace:"],
      "enabled": false,
      "description": "Skip workspace: protocol packages"
    }
  ],
  "ignorePaths": [
    "**/node_modules/**",
    "**/dist/**",
    "**/build/**",
    "packages/legacy/**"
  ]
}
```

### Workspace-Aware Pipeline

**.gitlab-ci.yml** - Monorepo pipeline integration:

```yaml
# Test affected workspaces after Renovate updates
test-affected-workspaces:
  stage: test
  image: node:18
  script:
    - |
      if [[ "$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME" =~ ^renovate/ ]]; then
        echo "Testing workspaces affected by Renovate updates"
        
        # Detect changed workspaces
        CHANGED_WORKSPACES=$(git diff --name-only origin/main | grep "^packages/" | cut -d'/' -f2 | sort -u)
        
        for workspace in $CHANGED_WORKSPACES; do
          echo "Testing workspace: $workspace"
          cd "packages/$workspace"
          npm test || exit 1
          cd ../..
        done
      fi
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event" && $CI_MERGE_REQUEST_SOURCE_BRANCH_NAME =~ /^renovate\//'

# Build and test entire monorepo
build-monorepo:
  stage: build
  image: node:18
  script:
    - npm ci
    - npm run build --workspaces
    - npm run test --workspaces
  rules:
    - if: '$GITLAB_USER_LOGIN == "renovate-bot"'
  artifacts:
    when: always
    reports:
      junit: "**/junit.xml"
```

## Custom Approval Workflows

### Conditional Auto-Approval

**.gitlab-ci.yml** - Smart approval logic:

```yaml
# Advanced Renovate approval workflow
renovate-approval-workflow:
  stage: .post
  image: alpine:latest
  before_script:
    - apk add --no-cache curl jq
  script:
    - |
      if [[ "$CI_PIPELINE_SOURCE" == "merge_request_event" ]] && \
         [[ "$GITLAB_USER_LOGIN" == "renovate-bot" ]]; then
        
        echo "Processing Renovate MR: $CI_MERGE_REQUEST_IID"
        
        # Get MR details
        MR_INFO=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                       "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID")
        
        TITLE=$(echo "$MR_INFO" | jq -r '.title')
        LABELS=$(echo "$MR_INFO" | jq -r '.labels[]' | tr '\n' ' ')
        
        echo "Title: $TITLE"
        echo "Labels: $LABELS"
        
        # Auto-approval logic
        SHOULD_AUTO_APPROVE=false
        
        # Approve patch updates for non-security packages
        if echo "$TITLE" | grep -qi "patch" && ! echo "$LABELS" | grep -qi "security"; then
          SHOULD_AUTO_APPROVE=true
          APPROVAL_REASON="Patch update for non-security package"
        fi
        
        # Approve dev dependencies
        if echo "$LABELS" | grep -qi "dev-deps"; then
          SHOULD_AUTO_APPROVE=true
          APPROVAL_REASON="Development dependency update"
        fi
        
        # Approve specific trusted packages
        TRUSTED_PACKAGES=("lodash" "moment" "uuid")
        for package in "${TRUSTED_PACKAGES[@]}"; do
          if echo "$TITLE" | grep -qi "$package"; then
            SHOULD_AUTO_APPROVE=true
            APPROVAL_REASON="Trusted package: $package"
            break
          fi
        done
        
        # Execute approval
        if [[ "$SHOULD_AUTO_APPROVE" == "true" ]]; then
          echo "Auto-approving MR: $APPROVAL_REASON"
          
          # Approve MR
          curl -X POST \
               --header "Private-Token: $RENOVATE_TOKEN" \
               "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/approve"
          
          # Add approval comment
          curl -X POST \
               --header "Private-Token: $RENOVATE_TOKEN" \
               --header "Content-Type: application/json" \
               --data "{\"body\": \"🤖 Auto-approved: $APPROVAL_REASON\"}" \
               "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes"
          
          # Optional: Auto-merge if conditions met
          if echo "$LABELS" | grep -qi "auto-merge"; then
            sleep 30  # Wait for CI to complete
            curl -X PUT \
                 --header "Private-Token: $RENOVATE_TOKEN" \
                 --header "Content-Type: application/json" \
                 --data '{"merge_when_pipeline_succeeds": true}' \
                 "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/merge"
          fi
        else
          echo "Manual review required for this update"
        fi
      fi
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event" && $GITLAB_USER_LOGIN == "renovate-bot"'
  allow_failure: true
```

## Security and Compliance Integration

### Security-First Configuration

**configs/presets/security-enhanced.json**:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "description": "Enhanced security-focused Renovate preset",
  "extends": ["config:recommended"],
  "vulnerabilityAlerts": {
    "enabled": true,
    "schedule": ["at any time"],
    "labels": ["security", "vulnerability", "critical"],
    "assignees": ["@security-team", "@ciso"],
    "reviewers": ["@security-team"],
    "automerge": false,
    "platformAutomerge": false
  },
  "osvVulnerabilityAlerts": true,
  "packageRules": [
    {
      "description": "Security packages - immediate processing",
      "matchPackagePatterns": ["*security*", "*auth*", "*crypto*"],
      "schedule": ["at any time"],
      "labels": ["security", "immediate"],
      "assignees": ["@security-team"],
      "reviewers": ["@security-team", "@tech-leads"],
      "automerge": false,
      "prPriority": 10
    },
    {
      "description": "Critical infrastructure packages",
      "matchPackageNames": [
        "express", "koa", "fastify",
        "django", "flask", "tornado",
        "spring-boot", "spring-security"
      ],
      "labels": ["critical-infrastructure", "security-review"],
      "assignees": ["@security-team", "@infrastructure-team"],
      "automerge": false,
      "minimumReleaseAge": "7 days"
    },
    {
      "description": "Database and ORM packages",
      "matchPackagePatterns": ["*sql*", "*orm*", "*db*"],
      "labels": ["database", "data-security"],
      "assignees": ["@dba-team", "@security-team"],
      "reviewers": ["@dba-team", "@security-team"],
      "automerge": false
    }
  ],
  "regexManagers": [
    {
      "description": "Security tool versions in CI",
      "fileMatch": ["^\\.gitlab-ci\\.ya?ml$"],
      "matchStrings": [
        "(?<depName>gitleaks|semgrep|trivy|clair|bandit|safety):(?<currentValue>[0-9.]+)"
      ],
      "datasourceTemplate": "docker",
      "depNameTemplate": "security-tools/{{depName}}"
    }
  ],
  "customManagers": [
    {
      "customType": "regex",
      "description": "Security policy versions",
      "fileMatch": ["^security/**/*.ya?ml$"],
      "matchStrings": [
        "version:\\s*[\"'](?<currentValue>[^\"']+)[\"']"
      ],
      "datasourceTemplate": "github-releases",
      "depNameTemplate": "security/policies"
    }
  ],
  "lockFileMaintenance": {
    "enabled": true,
    "schedule": ["before 5am every day"],
    "commitMessageAction": "Security lock file maintenance",
    "labels": ["security", "lock-maintenance"]
  }
}
```

### Compliance Integration

**.gitlab-ci.yml** - Compliance workflow:

```yaml
# Security compliance check for Renovate updates
security-compliance-check:
  stage: security
  image: python:3.11-alpine
  before_script:
    - pip install safety bandit semgrep
  script:
    - |
      if [[ "$GITLAB_USER_LOGIN" == "renovate-bot" ]]; then
        echo "Running security compliance checks on Renovate updates"
        
        # Safety check for Python dependencies
        if [ -f requirements.txt ]; then
          safety check -r requirements.txt --json > safety-report.json || true
        fi
        
        # Bandit security linting
        if [ -d src/ ]; then
          bandit -r src/ -f json -o bandit-report.json || true
        fi
        
        # Semgrep security analysis
        semgrep --config=auto --json --output=semgrep-report.json . || true
        
        # Generate compliance report
        python3 << 'EOF'
import json
import sys

def check_compliance():
    issues = []
    
    # Check safety report
    try:
        with open('safety-report.json', 'r') as f:
            safety_data = json.load(f)
            if safety_data.get('vulnerabilities'):
                issues.extend([f"Safety: {vuln['advisory']}" for vuln in safety_data['vulnerabilities']])
    except FileNotFoundError:
        pass
    
    # Check semgrep report
    try:
        with open('semgrep-report.json', 'r') as f:
            semgrep_data = json.load(f)
            if semgrep_data.get('results'):
                issues.extend([f"Semgrep: {result['message']}" for result in semgrep_data['results']])
    except FileNotFoundError:
        pass
    
    # Generate report
    with open('compliance-report.json', 'w') as f:
        json.dump({
            'compliant': len(issues) == 0,
            'issues_count': len(issues),
            'issues': issues[:10]  # Limit for readability
        }, f, indent=2)
    
    return len(issues) == 0

if not check_compliance():
    print("❌ Compliance issues found")
    sys.exit(1)
else:
    print("✅ Security compliance passed")
EOF
      fi
  artifacts:
    when: always
    paths:
      - "*-report.json"
      - compliance-report.json
    reports:
      sast: semgrep-report.json
  rules:
    - if: '$GITLAB_USER_LOGIN == "renovate-bot"'
  allow_failure: false
```

## Performance Optimization

### Intelligent Caching Strategy

**templates/renovate-optimized.yml**:

```yaml
variables:
  # Performance tuning
  RENOVATE_REPOSITORY_CACHE: enabled
  RENOVATE_OPTIMIZE_FOR_DISABLED: 'true'
  NODE_OPTIONS: "--max-old-space-size=8192"

.renovate-optimized:
  # Multi-tier caching strategy
  cache:
    - key: renovate-global-${CI_COMMIT_REF_SLUG}
      paths:
        - renovate/cache/renovate/repository/
      policy: pull-push
      when: always
    - key: renovate-npm-global
      paths:
        - .npm/
        - ~/.npm/
      policy: pull-push
    - key: renovate-others-${CI_COMMIT_REF_SLUG}
      paths:
        - renovate/cache/others/
      policy: pull-push
  
  before_script:
    # Optimize Git performance
    - git config --global core.preloadindex true
    - git config --global core.fscache true  
    - git config --global gc.auto 256
    
    # Pre-create cache directories
    - mkdir -p renovate/cache/{renovate/repository,others}
    - mkdir -p ~/.npm
    
    # Optimize Node.js performance
    - export NODE_OPTIONS="--max-old-space-size=8192 --optimize-for-size"
    
    # Pre-warm package registries
    - npm ping || true
    - python -m pip install --upgrade pip || true
  
  # Parallel execution strategy
  parallel:
    matrix:
      - BATCH_SIZE: ["20", "50", "100"]
        REPO_PATTERN: ["group1/*", "group2/*", "group3/*"]
  
  script:
    - |
      # Intelligent batch processing
      echo "Processing repositories: $REPO_PATTERN with batch size: $BATCH_SIZE"
      
      renovate \
        --autodiscover=true \
        --autodiscover-filter="$REPO_PATTERN" \
        --pr-concurrent-limit="$BATCH_SIZE" \
        --branch-concurrent-limit="$BATCH_SIZE" \
        $RENOVATE_EXTRA_FLAGS
```

### Repository Filtering and Batching

**config.js** - Smart repository handling:

```javascript
module.exports = {
  platform: 'gitlab',
  autodiscover: true,
  
  // Intelligent repository filtering
  autodiscoverFilter: getSmartFilter(),
  
  // Performance optimization
  repositoryCache: 'enabled',
  optimizeForDisabled: true,
  
  // Dynamic concurrency based on repository count
  prConcurrentLimit: getConcurrencyLimit(),
  branchConcurrentLimit: getConcurrencyLimit(),
  
  // Smart scheduling
  schedule: getSmartSchedule(),
  
  packageRules: [
    {
      description: "High-velocity repositories - more frequent updates",
      matchRepositories: ["frontend/*", "web/*"],
      schedule: ["after 6pm every weekday"],
      automerge: true
    },
    {
      description: "Critical repositories - weekend updates only", 
      matchRepositories: ["production/*", "critical/*"],
      schedule: ["after 10pm on saturday"],
      automerge: false,
      assignees: ["@production-team"]
    },
    {
      description: "Archived repositories - monthly updates",
      matchRepositories: ["archive/*", "legacy/*"],  
      schedule: ["before 5am on first day of month"],
      enabled: false  // Consider disabling entirely
    }
  ]
};

function getSmartFilter() {
  const totalRepos = process.env.TOTAL_REPOSITORIES || 50;
  const batchNumber = process.env.CI_NODE_INDEX || 1;
  const batchTotal = process.env.CI_NODE_TOTAL || 1;
  
  // Batch repositories across multiple pipeline runs
  if (totalRepos > 100 && batchTotal > 1) {
    const groups = ['group1/*', 'group2/*', 'group3/*', 'group4/*'];
    const batchSize = Math.ceil(groups.length / batchTotal);
    const startIndex = (batchNumber - 1) * batchSize;
    const batchGroups = groups.slice(startIndex, startIndex + batchSize);
    return `{${batchGroups.join(',')}}`;
  }
  
  return process.env.RENOVATE_AUTODISCOVER_FILTER || '*/*';
}

function getConcurrencyLimit() {
  const totalRepos = process.env.TOTAL_REPOSITORIES || 50;
  
  if (totalRepos > 200) return 50;
  if (totalRepos > 100) return 30;
  if (totalRepos > 50) return 20;
  return 10;
}

function getSmartSchedule() {
  const isHighTraffic = process.env.HIGH_TRAFFIC_PERIOD === 'true';
  
  if (isHighTraffic) {
    return ["after 11pm", "before 6am"];
  }
  
  return ["after 10pm every weekday", "every weekend"];
}
```

## Custom Package Managers

### Custom Registry Integration

**renovate.json** - Private registry configuration:

```json
{
  "hostRules": [
    {
      "matchHost": "npm.company.com",
      "hostType": "npm",
      "encrypted": {
        "token": "encrypted-npm-token"
      },
      "timeout": 60000
    },
    {
      "matchHost": "pypi.company.com", 
      "hostType": "pypi",
      "username": "renovate-bot",
      "encrypted": {
        "password": "encrypted-pypi-password"
      }
    },
    {
      "matchHost": "maven.company.com",
      "hostType": "maven",
      "headers": {
        "Authorization": "Bearer {{encrypted-maven-token}}"
      }
    }
  ],
  "registryUrls": [
    "https://npm.company.com/",
    "https://registry.npmjs.org/"
  ],
  "packageRules": [
    {
      "description": "Company internal packages",
      "matchPackagePatterns": ["^@company/"],
      "registryUrls": ["https://npm.company.com/"],
      "labels": ["internal", "company-package"],
      "reviewers": ["@package-maintainers"],
      "schedule": ["at any time"]
    }
  ]
}
```

### Custom Managers for Non-Standard Files

**renovate.json** - Advanced regex managers:

```json
{
  "regexManagers": [
    {
      "description": "Terraform module versions",
      "fileMatch": ["^.*\\.tf$"],
      "matchStrings": [
        "source\\s*=\\s*[\"']([^\"']+)[\"'].*?version\\s*=\\s*[\"'](?<currentValue>[^\"']+)[\"']"
      ],
      "datasourceTemplate": "terraform-module",
      "depNameTemplate": "{{{1}}}"
    },
    {
      "description": "Custom deployment manifests",
      "fileMatch": ["^deployments/.*\\.ya?ml$"],
      "matchStrings": [
        "image:\\s*(?<depName>[^:]+):(?<currentValue>[^\\s@]+)(@(?<currentDigest>sha256:[a-f0-9]+))?"
      ],
      "datasourceTemplate": "docker"
    },
    {
      "description": "Version variables in shell scripts",
      "fileMatch": ["^scripts/.*\\.(sh|bash)$"],
      "matchStrings": [
        "export\\s+(?<depName>[A-Z_]+)_VERSION=[\"'](?<currentValue>[^\"']+)[\"']"
      ],
      "datasourceTemplate": "github-releases",
      "depNameTemplate": "{{#switch depName}}{{#case 'KUBECTL'}}kubernetes/kubectl{{/case}}{{#case 'HELM'}}helm/helm{{/case}}{{#default}}{{depName}}{{/default}}{{/switch}}"
    }
  ],
  "customManagers": [
    {
      "customType": "regex",
      "description": "Jenkins pipeline library versions",
      "fileMatch": ["^Jenkinsfile$", "^jenkins/.*\\.groovy$"],
      "matchStrings": [
        "@Library\\([\"']([^@\"']+)@(?<currentValue>[^\"']+)[\"']\\)"
      ],
      "datasourceTemplate": "git-refs",
      "depNameTemplate": "jenkins-library/{{{1}}}"
    }
  ]
}
```

## Advanced Scheduling Patterns

### Time-Zone Aware Scheduling

**config.js** - Global scheduling coordination:

```javascript
const moment = require('moment-timezone');

module.exports = {
  platform: 'gitlab',
  
  // Multi-timezone coordination
  timezone: getOptimalTimezone(),
  schedule: getGlobalSchedule(),
  
  packageRules: [
    {
      description: "Asia-Pacific region repositories",
      matchRepositories: ["ap/*", "asia/*"],
      timezone: "Asia/Singapore", 
      schedule: ["after 10pm", "before 6am"]
    },
    {
      description: "European region repositories",
      matchRepositories: ["eu/*", "europe/*"],
      timezone: "Europe/London",
      schedule: ["after 10pm", "before 6am"]
    },
    {
      description: "Americas region repositories", 
      matchRepositories: ["us/*", "americas/*"],
      timezone: "America/New_York",
      schedule: ["after 10pm", "before 6am"]
    }
  ]
};

function getOptimalTimezone() {
  // Determine optimal timezone based on repository distribution
  const repoRegions = process.env.REPO_REGIONS?.split(',') || ['UTC'];
  const timezoneMap = {
    'asia': 'Asia/Singapore',
    'europe': 'Europe/London', 
    'americas': 'America/New_York',
    'utc': 'UTC'
  };
  
  return timezoneMap[repoRegions[0]] || 'UTC';
}

function getGlobalSchedule() {
  const now = moment();
  const isBusinessDay = now.isoWeekday() <= 5;
  const isBusinessHours = now.hour() >= 9 && now.hour() <= 17;
  
  if (isBusinessDay && !isBusinessHours) {
    return ["after 6pm", "before 9am"];
  }
  
  return ["every weekend", "after 10pm", "before 6am"];
}
```

## Integration with External Systems

### Slack/Teams Notification Integration

**.gitlab-ci.yml** - Advanced notifications:

```yaml
# Advanced notification system for Renovate updates
notify-renovate-status:
  stage: .post
  image: alpine:latest
  before_script:
    - apk add --no-cache curl jq
  script:
    - |
      # Collect pipeline statistics
      PIPELINE_STATUS=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                             "$CI_API_V4_URL/projects/$CI_PROJECT_ID/pipelines/$CI_PIPELINE_ID" | \
                             jq -r '.status')
      
      # Count MRs created/updated
      MR_COUNT=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                      "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests?author_username=renovate-bot&state=opened" | \
                      jq length)
      
      # Generate report
      REPORT="🤖 Renovate Runner Report\n"
      REPORT+="Pipeline: $PIPELINE_STATUS\n"
      REPORT+="Duration: $(( $(date +%s) - $CI_PIPELINE_CREATED_AT_UNIX )) seconds\n"
      REPORT+="Open MRs: $MR_COUNT\n"
      REPORT+="Repository Filter: $RENOVATE_AUTODISCOVER_FILTER\n"
      
      # Send to Slack
      if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
             --data "{\"text\":\"$REPORT\"}" \
             "$SLACK_WEBHOOK_URL"
      fi
      
      # Send to Teams
      if [ -n "$TEAMS_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
             --data "{\"text\":\"$REPORT\"}" \
             "$TEAMS_WEBHOOK_URL"
      fi
  rules:
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
  allow_failure: true
```

### JIRA Integration for Tracking

**config.js** - JIRA ticket creation:

```javascript
module.exports = {
  platform: 'gitlab',
  
  // JIRA integration for major updates
  packageRules: [
    {
      description: "Major updates require JIRA tickets",
      matchUpdateTypes: ["major"],
      additionalBranchPrefix: "jira-{{jiraTicket}}-",
      prBodyTemplate: `
## 📋 JIRA Ticket

This major update has been tracked in JIRA: [{{jiraTicket}}]({{jiraUrl}}/browse/{{jiraTicket}})

## 🔄 Changes

{{#each updates}}
- **{{depName}}**: {{currentValue}} → {{newValue}}
{{/each}}

## ⚠️ Impact Assessment Required

Please review the JIRA ticket for:
- Breaking change analysis
- Migration guide review  
- Test plan approval
- Rollback strategy

/cc @tech-leads @jira-integration-bot
      `,
      labels: ["major-update", "jira-tracked", "requires-assessment"]
    }
  ],
  
  // Custom JIRA ticket creation
  onboardingPrTitle: "🎯 Enable Renovate automated dependency updates",
  prBodyNotes: [
    "📊 **Metrics Dashboard**: [View dependency metrics]({{dashboardUrl}})",
    "🎫 **JIRA Integration**: Major updates automatically create JIRA tickets",
    "🔒 **Security**: Vulnerability alerts processed immediately"
  ]
};
```

This comprehensive guide covers advanced patterns that can be adapted and combined based on your specific organizational needs and infrastructure requirements.