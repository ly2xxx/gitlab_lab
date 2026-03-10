# Configu + GitLab CI Integration Lab

**Learn how to manage dynamic configuration in GitLab CI pipelines using Configu.**

---

## 📋 Lab Overview

This lab demonstrates **two approaches** to integrate Configu with GitLab CI:

- **Option A:** Export to `.env` file and source in shell
- **Option B:** Use Configu CLI with GitLab CI variables directly

Each approach has different benefits depending on your use case.

---

## 🗂️ Lab Structure

```
configu-ci-integration/
├── README.md                          # This file
├── option-a-env-export/
│   ├── .gitlab-ci.yml                 # Option A pipeline
│   ├── config.cfgu.json               # Configu schema
│   ├── deploy.sh                      # Deployment script
│   └── app.js                         # Sample Node.js app
├── option-b-direct-cli/
│   ├── .gitlab-ci.yml                 # Option B pipeline
│   ├── config.cfgu.json               # Configu schema
│   ├── deploy.sh                      # Deployment script
│   └── app.js                         # Sample Node.js app
└── comparison.md                      # Detailed comparison
```

---

## 🚀 Quick Start

### Prerequisites

1. **Configu CLI installed:**
   ```bash
   npm install -g @configu/cli
   ```

2. **Configu account** (free): https://app.configu.com

3. **GitLab repository** with CI/CD enabled

---

## 📊 Option A: Export to .env File

**How it works:**
1. Configu exports config to `.env` file
2. Shell sources the `.env` file
3. Variables available as environment variables
4. Scripts can access them via `$VAR_NAME`

**Best for:**
- ✅ Shell scripts and traditional deployments
- ✅ Docker builds needing `.env` files
- ✅ Teams familiar with `.env` workflows
- ✅ Tools that expect environment variables

**Pipeline example:**
```yaml
deploy:production:
  stage: deploy
  script:
    # Export Configu values to .env
    - configu export --set "production" --schema "./config.cfgu.json" > .env
    
    # Source the .env file
    - source .env
    
    # Now all variables are available
    - echo "Deploying to: $API_URL"
    - ./deploy.sh
```

**Try it:**
```bash
cd option-a-env-export
cat .gitlab-ci.yml
```

---

## 🔧 Option B: Direct CLI Integration

**How it works:**
1. Configu eval fetches config values
2. Pipe directly to scripts or commands
3. No intermediate `.env` file
4. GitLab CI variables passed via environment

**Best for:**
- ✅ Kubernetes/Helm deployments
- ✅ GitLab Auto DevOps workflows
- ✅ JSON/YAML templating
- ✅ Audit trails (no file artifacts)

**Pipeline example:**
```yaml
deploy:production:
  stage: deploy
  script:
    # Fetch and use config in one command
    - |
      configu eval --set "production" --schema "./config.cfgu.json" \
        --format "export" | sh
    
    # Or pipe to jq for JSON processing
    - |
      configu eval --set "production" --schema "./config.cfgu.json" \
        --format "json" | jq -r '.API_URL'
```

**Try it:**
```bash
cd option-b-direct-cli
cat .gitlab-ci.yml
```

---

## 🎯 Comparison Matrix

| Feature | Option A (.env Export) | Option B (Direct CLI) |
|---------|------------------------|----------------------|
| **Ease of Use** | ⭐⭐⭐⭐⭐ Simple | ⭐⭐⭐ Moderate |
| **Performance** | ⭐⭐⭐ (File I/O) | ⭐⭐⭐⭐ (In-memory) |
| **Security** | ⭐⭐⭐ (.env artifacts) | ⭐⭐⭐⭐⭐ (No files) |
| **Debugging** | ⭐⭐⭐⭐⭐ (inspect .env) | ⭐⭐⭐ (ephemeral) |
| **Docker Friendly** | ⭐⭐⭐⭐⭐ (native) | ⭐⭐⭐ (workarounds) |
| **K8s/Helm** | ⭐⭐⭐ (need conversion) | ⭐⭐⭐⭐⭐ (native) |
| **GitLab Variables** | ⭐⭐⭐ (manual export) | ⭐⭐⭐⭐⭐ (automatic) |
| **Audit Trail** | ⭐⭐⭐ (file in logs) | ⭐⭐⭐⭐ (Configu only) |

---

## 🏃 Running the Labs

### Test Option A Locally

```bash
cd option-a-env-export

# 1. Create a Configu config set
configu set create --name "production"

# 2. Set some values
configu set upsert --set "production" --key "API_URL" --value "https://api.prod.example.com"
configu set upsert --set "production" --key "DB_HOST" --value "prod-db.example.com"

# 3. Export to .env
configu export --set "production" --schema "./config.cfgu.json" > .env

# 4. Source and verify
source .env
echo "API_URL: $API_URL"

# 5. Run deployment script
./deploy.sh
```

### Test Option B Locally

```bash
cd option-b-direct-cli

# 1. Create config (same as above)
configu set create --name "production"
configu set upsert --set "production" --key "API_URL" --value "https://api.prod.example.com"

# 2. Evaluate and use directly
configu eval --set "production" --schema "./config.cfgu.json" --format "export" | sh

# 3. Or get JSON output
configu eval --set "production" --schema "./config.cfgu.json" --format "json"

# 4. Run deployment
./deploy.sh
```

---

## 🔐 Secrets Management

Both options support **GitLab CI Variables** for sensitive data:

**In GitLab project settings:**
```
Settings → CI/CD → Variables
Add variable: CONFIGU_TOKEN
```

**In .gitlab-ci.yml:**
```yaml
variables:
  CONFIGU_ORG: "your-org"
  CONFIGU_TOKEN: $CONFIGU_API_TOKEN  # Protected variable
```

**Best practice:**
- Store non-sensitive config in Configu
- Store secrets in GitLab CI Variables
- Reference GitLab secrets in Configu schema

---

## 📈 Real-World Examples

### Use Case 1: Multi-Environment Deployment

**Scenario:** Deploy same app to dev/staging/prod with different configs

**Option A approach:**
```yaml
.deploy_template:
  script:
    - configu export --set "$CI_ENVIRONMENT_NAME" --schema "./config.cfgu.json" > .env
    - source .env
    - docker-compose up -d

deploy:dev:
  extends: .deploy_template
  environment: dev

deploy:prod:
  extends: .deploy_template
  environment: production
```

**Option B approach:**
```yaml
.deploy_template:
  script:
    - |
      configu eval --set "$CI_ENVIRONMENT_NAME" --schema "./config.cfgu.json" \
        --format "json" > config.json
    - helm upgrade --install myapp ./chart --values config.json

deploy:dev:
  extends: .deploy_template
  environment: dev
```

---

### Use Case 2: Feature Flags

**Scenario:** Enable/disable features based on environment

**Configu schema (config.cfgu.json):**
```json
{
  "FEATURE_NEW_UI": {
    "type": "Boolean",
    "default": false,
    "description": "Enable new UI"
  },
  "FEATURE_ANALYTICS": {
    "type": "Boolean",
    "default": false
  }
}
```

**Pipeline:**
```yaml
test:feature-flags:
  script:
    - configu export --set "staging" --schema "./config.cfgu.json" > .env
    - source .env
    - |
      if [ "$FEATURE_NEW_UI" = "true" ]; then
        echo "Testing new UI..."
        npm run test:new-ui
      fi
```

---

### Use Case 3: Dynamic Docker Builds

**Scenario:** Pass build-time variables to Docker

**Option A (recommended):**
```yaml
build:
  script:
    - configu export --set "production" --schema "./config.cfgu.json" > .env
    - docker build --build-arg-file .env -t myapp:latest .
```

**Dockerfile:**
```dockerfile
ARG API_URL
ARG DB_HOST
ENV API_URL=${API_URL}
ENV DB_HOST=${DB_HOST}
```

---

## 🛠️ Troubleshooting

### Error: "Configu command not found"

**Solution:** Install Configu CLI in your pipeline:
```yaml
before_script:
  - npm install -g @configu/cli
```

### Error: "Set not found"

**Solution:** Create the config set first:
```bash
configu set create --name "production"
```

### Error: "Authentication failed"

**Solution:** Set `CONFIGU_TOKEN` in GitLab CI Variables:
```
Settings → CI/CD → Variables → Add variable
```

---

## 📚 Additional Resources

- **Configu Docs:** https://docs.configu.com
- **GitLab CI Docs:** https://docs.gitlab.com/ee/ci/
- **Configu + GitLab Guide:** https://docs.configu.com/integrations/gitlab
- **Example Repo:** https://github.com/configu/examples

---

## 🎓 Next Steps

1. **Run both labs locally** to understand the differences
2. **Push to GitLab** and trigger CI/CD pipelines
3. **Test with multiple environments** (dev/staging/prod)
4. **Add secrets management** using GitLab CI Variables
5. **Integrate with your real projects**

---

## 💡 Recommendation

**For new projects:**
- Start with **Option A** (simpler, easier to debug)
- Graduate to **Option B** when you need advanced features

**For Kubernetes/Cloud-native:**
- Go with **Option B** (JSON/YAML native)

**For traditional deployments:**
- Use **Option A** (shell-friendly)

---

## 🤝 Contributing

Found a better pattern? Open an issue or PR!

**Author:** Master Yang  
**Date:** 2026-03-10  
**License:** MIT
