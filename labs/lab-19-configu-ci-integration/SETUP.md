# Quick Setup Guide

## Prerequisites

1. **Configu CLI** (required)
   ```bash
   npm install -g @configu/cli
   ```

2. **Configu Account** (free)
   - Sign up: https://app.configu.com
   - Get your organization name

3. **jq** (for Option B)
   - Linux: `sudo apt-get install jq`
   - macOS: `brew install jq`
   - Windows: `choco install jq` or download from https://stedolan.github.io/jq/

---

## Initial Configu Setup

### 1. Login to Configu

```bash
configu login
```

### 2. Create Configuration Sets

```bash
# Create environments
configu set create --name "development"
configu set create --name "staging"
configu set create --name "production"
```

### 3. Populate Development Config

```bash
cd option-a-env-export  # or option-b-direct-cli

# Set configuration values
configu set upsert --set "development" --key "API_URL" --value "http://localhost:3000"
configu set upsert --set "development" --key "DB_HOST" --value "localhost"
configu set upsert --set "development" --key "DB_PORT" --value "5432"
configu set upsert --set "development" --key "DB_NAME" --value "myapp_dev"
configu set upsert --set "development" --key "REDIS_URL" --value "redis://localhost:6379"
configu set upsert --set "development" --key "LOG_LEVEL" --value "debug"
configu set upsert --set "development" --key "MAX_CONNECTIONS" --value "50"
configu set upsert --set "development" --key "FEATURE_NEW_UI" --value "true"
configu set upsert --set "development" --key "FEATURE_ANALYTICS" --value "false"
configu set upsert --set "development" --key "SESSION_TIMEOUT" --value "3600"
configu set upsert --set "development" --key "RATE_LIMIT" --value "100"
configu set upsert --set "development" --key "CORS_ORIGINS" --value "*"
configu set upsert --set "development" --key "CACHE_TTL" --value "300"
configu set upsert --set "development" --key "ENV_NAME" --value "development"
```

### 4. Populate Staging Config

```bash
configu set upsert --set "staging" --key "API_URL" --value "https://api.staging.example.com"
configu set upsert --set "staging" --key "DB_HOST" --value "staging-db.example.com"
configu set upsert --set "staging" --key "DB_PORT" --value "5432"
configu set upsert --set "staging" --key "DB_NAME" --value "myapp_staging"
configu set upsert --set "staging" --key "REDIS_URL" --value "redis://staging-redis:6379"
configu set upsert --set "staging" --key "LOG_LEVEL" --value "info"
configu set upsert --set "staging" --key "MAX_CONNECTIONS" --value "100"
configu set upsert --set "staging" --key "FEATURE_NEW_UI" --value "true"
configu set upsert --set "staging" --key "FEATURE_ANALYTICS" --value "true"
configu set upsert --set "staging" --key "SESSION_TIMEOUT" --value "3600"
configu set upsert --set "staging" --key "RATE_LIMIT" --value "200"
configu set upsert --set "staging" --key "CORS_ORIGINS" --value "https://staging.example.com"
configu set upsert --set "staging" --key "CACHE_TTL" --value "600"
configu set upsert --set "staging" --key "ENV_NAME" --value "staging"
```

### 5. Populate Production Config

```bash
configu set upsert --set "production" --key "API_URL" --value "https://api.example.com"
configu set upsert --set "production" --key "DB_HOST" --value "prod-db.example.com"
configu set upsert --set "production" --key "DB_PORT" --value "5432"
configu set upsert --set "production" --key "DB_NAME" --value "myapp_prod"
configu set upsert --set "production" --key "REDIS_URL" --value "redis://prod-redis:6379"
configu set upsert --set "production" --key "LOG_LEVEL" --value "warn"
configu set upsert --set "production" --key "MAX_CONNECTIONS" --value "500"
configu set upsert --set "production" --key "FEATURE_NEW_UI" --value "true"
configu set upsert --set "production" --key "FEATURE_ANALYTICS" --value "true"
configu set upsert --set "production" --key "SESSION_TIMEOUT" --value "7200"
configu set upsert --set "production" --key "RATE_LIMIT" --value "1000"
configu set upsert --set "production" --key "CORS_ORIGINS" --value "https://example.com,https://www.example.com"
configu set upsert --set "production" --key "CACHE_TTL" --value "3600"
configu set upsert --set "production" --key "ENV_NAME" --value "production"
```

---

## Testing Locally

### Test Option A (env export)

```bash
cd option-a-env-export

# 1. Export config to .env
configu export --set "development" --schema "./config.cfgu.json" > .env

# 2. Verify .env file
cat .env

# 3. Source it
source .env

# 4. Verify variables
echo "API_URL: $API_URL"
echo "DB_HOST: $DB_HOST"
echo "ENV_NAME: $ENV_NAME"

# 5. Run deployment script
chmod +x ./deploy.sh
./deploy.sh

# 6. (Optional) Run app
node app.js
# Then visit: http://localhost:3000

# 7. Cleanup
rm .env
```

---

### Test Option B (direct CLI)

```bash
cd option-b-direct-cli

# Method 1: Export to shell
configu eval --set "development" --schema "./config.cfgu.json" --format "export" | sh

# Verify
echo "API_URL: $API_URL"
echo "DB_HOST: $DB_HOST"

# Run deployment
chmod +x ./deploy.sh
./deploy.sh

# Method 2: JSON output
configu eval --set "development" --schema "./config.cfgu.json" --format "json" > config.json

# Inspect JSON
cat config.json | jq '.'

# Run app with JSON config
node app.js --config config.json
# Then visit: http://localhost:3000

# Cleanup
rm config.json
```

---

## GitLab CI Setup

### 1. Get Configu API Token

```bash
# Option 1: Use existing session
configu config get token

# Option 2: Create dedicated CI token at:
# https://app.configu.com/settings/tokens
```

### 2. Add to GitLab CI Variables

1. Go to your GitLab project
2. Settings → CI/CD → Variables → Expand
3. Add variable:
   - Key: `CONFIGU_API_TOKEN`
   - Value: `cfgu_xxxxx...` (your token)
   - Type: Variable
   - Protected: ✅ Yes
   - Masked: ✅ Yes

### 3. Push to GitLab

```bash
# Initialize Git (if not already)
git init
git add .
git commit -m "Add Configu CI integration lab"

# Add GitLab remote
git remote add origin https://gitlab.com/your-org/your-repo.git

# Push
git push -u origin main
```

### 4. Trigger Pipeline

- Push a commit or tag
- Watch the pipeline run
- Check deployment logs

---

## Troubleshooting

### "Configu command not found"

**Solution:**
```bash
npm install -g @configu/cli
configu --version
```

### "Set not found"

**Solution:** Create the set first:
```bash
configu set create --name "development"
```

### "Authentication failed"

**Solution:** Login again:
```bash
configu login
```

### "jq: command not found" (Option B)

**Solution:**
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Windows
choco install jq
```

### ".env file empty"

**Solution:** Check if config values exist:
```bash
configu set list --set "development"
```

---

## Next Steps

1. ✅ Complete setup above
2. ✅ Test both options locally
3. ✅ Read `comparison.md` to choose approach
4. ✅ Push to GitLab and test CI/CD
5. ✅ Adapt to your real project

---

## Automated Setup Script

Save this as `setup.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Configu Lab Setup Script"
echo "=============================="

# Check prerequisites
command -v npm >/dev/null 2>&1 || { echo "❌ npm not found. Install Node.js first."; exit 1; }
command -v configu >/dev/null 2>&1 || { echo "📦 Installing Configu CLI..."; npm install -g @configu/cli; }

echo "✅ Prerequisites OK"

# Login
echo ""
echo "🔐 Please login to Configu..."
configu login

# Create sets
echo ""
echo "📋 Creating configuration sets..."
for env in development staging production; do
  configu set create --name "$env" || echo "   (Set $env may already exist)"
done

echo ""
echo "✅ Setup complete!"
echo ""
echo "📚 Next steps:"
echo "   1. Run: cd option-a-env-export"
echo "   2. Run: configu export --set development --schema ./config.cfgu.json > .env"
echo "   3. Run: source .env && node app.js"
echo ""
echo "💡 Or try Option B:"
echo "   1. Run: cd option-b-direct-cli"
echo "   2. Run: configu eval --set development --schema ./config.cfgu.json --format export | sh"
echo "   3. Run: node app.js"
```

Run it:
```bash
chmod +x setup.sh
./setup.sh
```

---

**You're ready to go! 🎉**

Questions? Check `README.md` and `comparison.md`
