# Lab 16: Mend Renovate Community Edition Setup

## Overview
This lab demonstrates how to set up Mend Renovate Community Edition with GitLab CE, including feature branch workflows, automated dependency management, and webhook integration for real-time updates.

## Learning Objectives
- Set up Mend Renovate Community Edition with Docker
- Configure GitLab bot account and Personal Access Token (PAT)
- Implement webhook configuration for real-time updates
- Create and manage feature branches for dependency updates
- Configure automated dependency management with renovate.json
- Test the complete workflow from dependency detection to merge request creation

## Prerequisites
- Docker and Docker Compose installed
- GitLab CE instance running (from lab-00)
- Basic knowledge of Git workflows
- Node.js project for testing (provided in this lab)

## Lab Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   GitLab CE         │    │  Renovate Server    │    │  Test Project       │
│  - Bot Account      │◄──►│  - Webhooks         │◄──►│  - package.json     │
│  - Webhooks         │    │  - Scheduler        │    │  - renovate.json    │
│  - Projects         │    │  - Docker Container │    │  - Dependencies     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Directory Structure
```
lab-16-mend-renovate/
├── README.md                    # This file
├── docker-compose.yml           # Renovate CE setup
├── .env.example                 # Environment variables template
├── renovate/
│   ├── config.js                # Renovate CLI configuration
│   └── logs/                    # Log directory
├── sample-project/              # Test Node.js project
│   ├── package.json             # Dependencies to update
│   ├── renovate.json            # Renovate configuration
│   ├── .gitlab-ci.yml           # CI/CD pipeline
│   └── src/
│       └── app.js               # Sample application
├── scripts/
│   ├── setup.sh                 # Initial setup script
│   ├── test-webhooks.sh         # Webhook testing
│   └── validate.sh              # Validation script
└── docs/
    ├── bot-setup.md             # Bot account setup
    ├── webhook-config.md        # Webhook configuration
    └── troubleshooting.md       # Common issues and solutions
```

## Part 1: Environment Setup

### Step 1: Clone and Create Feature Branch
```bash
# Clone the repository
git clone <your-gitlab-repo>
cd <your-project>

# Create feature branch for renovate setup
git checkout -b feature/setup-renovate
```

### Step 2: Set Up Environment Variables
Copy the environment template:
```bash
cp labs/lab-16-mend-renovate/.env.example labs/lab-16-mend-renovate/.env
```

Edit the `.env` file with your specific values:
```bash
# Required - Accept Mend Terms of Service
MEND_RNV_ACCEPT_TOS=y

# Required - License key (Community Edition)
MEND_RNV_LICENSE_KEY=eyJsaW1pdCI6IjEwIn0=.30440220457941b71ea8eb345c729031718b692169f0ce2cf020095fd328812f4d7d5bc1022022648d1a29e71d486f89f27bdc8754dfd6df0ddda64a23155000a61a105da2a1

# Required - Platform configuration
MEND_RNV_PLATFORM=gitlab
MEND_RNV_ENDPOINT=http://localhost:8080/api/v4/
MEND_RNV_SERVER_PORT=8080

# Required - GitLab bot credentials (setup in Part 2)
MEND_RNV_GITLAB_PAT=your_gitlab_pat_here

# Required - GitHub.com token for public packages
GITHUB_COM_TOKEN=your_github_token_here

# Optional - Webhook configuration
MEND_RNV_WEBHOOK_SECRET=renovate-webhook-secret
MEND_RNV_WEBHOOK_URL=http://renovate:8080/webhook

# Optional - Admin API
MEND_RNV_ADMIN_API_ENABLED=true
MEND_RNV_SERVER_API_SECRET=admin-api-secret

# Optional - Scheduling
RENOVATE_CRON_JOB_SCHEDULER=0 2 * * *
```

## Part 2: GitLab Bot Account Setup

### Step 1: Create Renovate Bot Account

1. **Access your GitLab CE instance** (from lab-00):
   ```bash
   # Start GitLab CE if not running
   cd labs/lab-00-gitlab-self-host-docker
   docker-compose up -d
   ```

2. **Create new user account**:
   - Navigate to `http://localhost:8080`
   - Admin Area → Users → New User
   - Username: `renovate-bot`
   - Name: `Renovate Bot`
   - Email: `renovate-bot@example.local`
   - Set temporary password

3. **Configure bot account**:
   - Login as renovate-bot
   - Change password
   - Add SSH key if needed

### Step 2: Generate Personal Access Token (PAT)

1. **Navigate to User Settings**:
   - Profile → Preferences → Access Tokens

2. **Create new token**:
   - Name: `Renovate CE Token`
   - Scopes: `api`, `read_user`, `write_repository`
   - Expiration: Set appropriate date
   - Click "Create personal access token"

3. **Save the PAT**:
   ```bash
   # Update your .env file
   MEND_RNV_GITLAB_PAT=glpat-xxxxxxxxxxxxxxxx
   ```

### Step 3: Grant Bot Permissions

For each project you want Renovate to manage:
1. Navigate to Project → Members
2. Add `renovate-bot` with `Developer` role minimum
3. For webhook auto-creation, use `Maintainer` role

## Part 3: Start Renovate Community Edition

### Step 1: Launch Renovate Server
```bash
cd labs/lab-16-mend-renovate
docker-compose up -d
```

### Step 2: Verify Installation
```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f renovate-ce

# Test API endpoint
curl -X GET http://localhost:8080/api/health
```

### Step 3: Configure Webhooks (Automatic)

If you set `MEND_RNV_WEBHOOK_URL`, webhooks will be created automatically. Otherwise, set up manually:

1. **Project Webhooks** (per project):
   - Project → Settings → Webhooks
   - URL: `http://localhost:8080/webhook`
   - Secret Token: `renovate-webhook-secret`
   - Triggers: Push events, Issues events, Merge request events

2. **Group Webhooks** (covers all projects):
   - Group → Settings → Webhooks  
   - Same configuration as above

## Part 4: Create Sample Project

### Step 1: Initialize Sample Project
```bash
# Create new project in GitLab
# Name: renovate-test-project

# Clone locally
git clone http://localhost:8080/root/renovate-test-project.git
cd renovate-test-project

# Copy sample project files
cp -r ../gitlab_lab/labs/lab-16-mend-renovate/sample-project/* .
```

### Step 2: Review Sample Files

**package.json** - Dependencies to update:
```json
{
  "name": "renovate-test-project",
  "version": "1.0.0",
  "description": "Test project for Renovate automation",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "test": "echo \"No tests yet\" && exit 0",
    "lint": "echo \"No linting configured\" && exit 0"
  },
  "dependencies": {
    "express": "^4.17.1",
    "lodash": "^4.17.20",
    "axios": "^0.21.1"
  },
  "devDependencies": {
    "nodemon": "^2.0.7",
    "jest": "^26.6.0"
  }
}
```

**renovate.json** - Renovate configuration:
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended"
  ],
  "platform": "gitlab",
  "gitlabUrl": "http://localhost:8080",
  "dependencyDashboard": true,
  "labels": ["dependencies"],
  "assignees": ["@renovate-bot"],
  "reviewers": ["@root"],
  "schedule": ["before 6am"],
  "timezone": "UTC",
  "packageRules": [
    {
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true,
      "automergeType": "pr",
      "platformAutomerge": true
    },
    {
      "matchUpdateTypes": ["major"],
      "addLabels": ["major-update"],
      "reviewers": ["@root"]
    }
  ],
  "prConcurrentLimit": 10,
  "branchConcurrentLimit": 10,
  "rebaseWhen": "behind-base-branch",
  "lockFileMaintenance": {
    "enabled": true,
    "schedule": ["before 5am on monday"]
  }
}
```

### Step 3: Commit and Push Initial Files
```bash
git add .
git commit -m "Initial project setup with outdated dependencies"
git push origin main
```

## Part 5: Feature Branch Workflow

### Step 1: Enable Renovate on Project

1. **Add renovate-bot as project member** (if not done)
2. **Trigger initial Renovate scan**:
   ```bash
   # Manual trigger via API (if admin API enabled)
   curl -X POST http://localhost:8080/webhook \
     -H "Content-Type: application/json" \
     -H "X-Gitlab-Token: renovate-webhook-secret" \
     -d '{
       "object_kind": "push",
       "project": {
         "path_with_namespace": "root/renovate-test-project"
       }
     }'
   ```

### Step 2: Monitor Renovate Activity

1. **Check Renovate logs**:
   ```bash
   docker-compose logs -f renovate-ce | grep renovate-test-project
   ```

2. **Expected Renovate actions**:
   - Create "Dependency Dashboard" issue
   - Create feature branches for each dependency update
   - Open merge requests for each update

### Step 3: Review Generated Merge Requests

Renovate should create MRs like:
- `renovate/express-4.x` - Update Express.js
- `renovate/lodash-4.x` - Update Lodash  
- `renovate/axios-1.x` - Update Axios

Each MR will contain:
- Updated package.json and package-lock.json
- Detailed changelog information
- Automated tests (if configured)

### Step 4: Feature Branch Code Modification

Let's simulate manual code changes alongside Renovate:

```bash
# Create feature branch for new functionality
git checkout -b feature/add-health-endpoint

# Modify src/app.js to add health endpoint
cat >> src/app.js << 'EOF'

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});
EOF

# Commit changes
git add .
git commit -m "Add health check endpoint"
git push origin feature/add-health-endpoint
```

### Step 5: Create Manual Merge Request

1. Navigate to GitLab web interface
2. Create MR from `feature/add-health-endpoint` to `main`
3. Add description and assign reviewers
4. Observe how it coexists with Renovate MRs

### Step 6: Merge Workflow Testing

1. **Review and merge Renovate MRs**:
   - Check automated tests pass
   - Review dependency changes
   - Merge approved updates

2. **Handle merge conflicts** (if any):
   ```bash
   # Update your feature branch with latest main
   git checkout feature/add-health-endpoint
   git rebase main
   git push --force-with-lease origin feature/add-health-endpoint
   ```

## Part 6: Testing and Validation

### Step 1: Run Validation Script
```bash
cd labs/lab-16-mend-renovate
./scripts/validate.sh
```

### Step 2: Test Webhook Integration
```bash
./scripts/test-webhooks.sh
```

### Step 3: Verify Renovate Configuration
```bash
# Check Renovate config validation
docker run --rm -v $(pwd)/sample-project:/tmp/project \
  renovate/renovate:latest \
  renovate-config-validator /tmp/project/renovate.json
```

## Part 7: Advanced Configuration

### Customizing Renovate Behavior

**renovate.json** - Advanced settings:
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    ":dependencyDashboard",
    ":semanticCommits",
    ":separateMajorReleases",
    "group:monorepos",
    "group:recommended",
    "workarounds:all"
  ],
  "schedule": ["after 10pm every weekday", "before 5am every weekday", "every weekend"],
  "timezone": "America/New_York",
  "labels": ["renovate", "dependencies"],
  "assigneesFromCodeOwners": true,
  "reviewersFromCodeOwners": true,
  "platformAutomerge": true,
  "packageRules": [
    {
      "description": "Auto-merge non-major updates",
      "matchUpdateTypes": ["minor", "patch", "pin", "digest"],
      "automerge": true
    },
    {
      "description": "Group ESLint packages",
      "matchPackageNames": ["eslint"],
      "matchPackagePatterns": ["^eslint-"],
      "groupName": "ESLint and plugins"
    },
    {
      "description": "Update Docker tags more frequently",
      "matchDatasources": ["docker"],
      "schedule": ["after 10pm on sunday"]
    }
  ],
  "vulnerabilityAlerts": {
    "enabled": true,
    "schedule": ["at any time"]
  },
  "osvVulnerabilityAlerts": true
}
```

### GitLab CI/CD Integration

**.gitlab-ci.yml** - Pipeline with Renovate integration:
```yaml
stages:
  - validate
  - test
  - security
  - build
  - deploy

variables:
  NODE_VERSION: "18"

.node-job: &node-job
  image: node:${NODE_VERSION}
  cache:
    paths:
      - node_modules/
  before_script:
    - npm ci

validate-dependencies:
  <<: *node-job
  stage: validate
  script:
    - npm audit --audit-level=high
    - npx lockfile-lint --path package-lock.json --validate-https --allowed-hosts npm
  only:
    - merge_requests
    - main

test:
  <<: *node-job
  stage: test
  script:
    - npm test
    - npm run lint
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

security-scan:
  stage: security
  image: 
    name: returntocorp/semgrep-agent:v1
    entrypoint: [""]
  script:
    - semgrep-agent --config=auto
  only:
    - merge_requests
    - main

# Auto-approve Renovate MRs for minor/patch updates
auto-approve-renovate:
  image: alpine/git
  stage: validate
  script:
    - |
      if [ "$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME" != "" ] && 
         [ "$GITLAB_USER_LOGIN" = "renovate-bot" ]; then
        echo "Auto-approving Renovate MR..."
        # Add auto-approval logic here
      fi
  only:
    - merge_requests
  when: manual
```

## Part 8: Monitoring and Maintenance

### Monitoring Renovate

1. **Health Check Endpoint**:
   ```bash
   curl http://localhost:8080/api/health
   ```

2. **Admin API** (if enabled):
   ```bash
   # Get server info
   curl -H "X-API-Key: admin-api-secret" \
        http://localhost:8080/api/admin/info

   # Trigger repo sync
   curl -X POST \
        -H "X-API-Key: admin-api-secret" \
        -H "Content-Type: application/json" \
        -d '{"repository": "root/renovate-test-project"}' \
        http://localhost:8080/api/admin/repos/sync
   ```

3. **Log Analysis**:
   ```bash
   # Filter for errors
   docker-compose logs renovate-ce | grep ERROR

   # Monitor webhook activity  
   docker-compose logs renovate-ce | grep webhook
   ```

### Backup and Recovery

```bash
# Backup Renovate configuration
tar -czf renovate-backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml .env renovate/

# Backup GitLab data (covered in lab-00)
```

## Part 9: Troubleshooting

### Common Issues

1. **Renovate not creating MRs**:
   - Check bot permissions (Developer minimum)
   - Verify PAT scopes and expiration
   - Check webhook configuration
   - Review Renovate logs for errors

2. **Webhook not triggering**:
   - Verify webhook URL accessibility
   - Check secret token matching
   - Ensure proper event triggers enabled
   - Test webhook manually

3. **Authentication errors**:
   - Regenerate GitLab PAT
   - Check GitHub token for public packages
   - Verify bot account not locked

4. **Memory issues**:
   - Increase Docker container memory
   - Adjust concurrent limits in renovate.json
   - Monitor resource usage

### Debugging Commands

```bash
# Check container resources
docker stats renovate-ce

# Validate renovate.json
npx renovate-config-validator renovate.json

# Test GitLab API connectivity
curl -H "Private-Token: $MEND_RNV_GITLAB_PAT" \
     http://localhost:8080/api/v4/user

# Manual webhook test
curl -X POST http://localhost:8080/webhook \
  -H "Content-Type: application/json" \
  -H "X-Gitlab-Token: renovate-webhook-secret" \
  -d @scripts/test-webhook-payload.json
```

## Cleanup

```bash
# Stop Renovate
docker-compose down

# Remove containers and volumes
docker-compose down -v

# Remove test project
rm -rf renovate-test-project

# Switch back to main branch
git checkout main
git branch -D feature/setup-renovate feature/add-health-endpoint
```

## Summary

In this lab, you have:

✅ Set up Mend Renovate Community Edition with Docker  
✅ Created and configured GitLab bot account with proper permissions  
✅ Implemented webhook integration for real-time updates  
✅ Created feature branches and demonstrated Git workflow  
✅ Configured automated dependency management  
✅ Tested the complete cycle from dependency detection to merge request  
✅ Implemented advanced Renovate configuration options  
✅ Set up monitoring and troubleshooting procedures  

## Next Steps

- **Lab 17**: Advanced Renovate patterns and monorepo management
- **Lab 18**: Security scanning integration with Renovate
- **Lab 19**: Custom Renovate rules and package grouping
- **Lab 20**: Renovate performance optimization and scaling

## Additional Resources

- [Mend Renovate Community Edition Documentation](https://github.com/mend/renovate-ce-ee)
- [Renovate Configuration Options](https://docs.renovatebot.com/configuration-options/)
- [GitLab Webhooks Documentation](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html)
- [Renovate Best Practices](https://docs.renovatebot.com/best-practices/)
