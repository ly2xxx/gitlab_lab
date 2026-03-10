#!/bin/bash
# deploy.sh - Example deployment script for Option B
# This script expects environment variables from Configu CLI direct export

set -e
set -u

echo "=================================================="
echo "🚀 Deployment Script - Option B (Direct CLI)"
echo "=================================================="

# Validate required environment variables
echo ""
echo "🔍 Validating environment variables..."

REQUIRED_VARS=("API_URL" "DB_HOST" "ENV_NAME")

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "❌ ERROR: Required variable $var is not set!"
    echo "💡 Hint: Run 'configu eval --set <env> --schema ./config.cfgu.json --format export | sh' first"
    exit 1
  fi
  echo "✅ $var = ${!var}"
done

echo ""
echo "📊 Current Configuration (from Configu CLI):"
echo "=================================================="
echo "Environment:     $ENV_NAME"
echo "API URL:         $API_URL"
echo "Database Host:   $DB_HOST"
echo "Database Port:   ${DB_PORT:-5432}"
echo "Database Name:   ${DB_NAME:-myapp}"
echo "Redis URL:       ${REDIS_URL:-not set}"
echo "Log Level:       ${LOG_LEVEL:-info}"
echo "Max Connections: ${MAX_CONNECTIONS:-100}"
echo "Cache TTL:       ${CACHE_TTL:-300}s"
echo "Rate Limit:      ${RATE_LIMIT:-100}/min"
echo "Session Timeout: ${SESSION_TIMEOUT:-3600}s"
echo "CORS Origins:    ${CORS_ORIGINS:-*}"
echo "=================================================="

# Feature flags
echo ""
echo "🎚️  Feature Flags:"
if [ "${FEATURE_NEW_UI:-false}" = "true" ]; then
  echo "  ✅ NEW UI: Enabled"
else
  echo "  ⏭️  NEW UI: Disabled"
fi

if [ "${FEATURE_ANALYTICS:-false}" = "true" ]; then
  echo "  ✅ ANALYTICS: Enabled"
else
  echo "  ⏭️  ANALYTICS: Disabled"
fi

# Environment-specific deployment logic
echo ""
echo "📦 Deploying application to $ENV_NAME..."
echo "=================================================="

case "$ENV_NAME" in
  development)
    echo "🔧 Development deployment mode"
    echo "   - Hot reload enabled"
    echo "   - Debug logging enabled"
    echo "   - CORS: Allow all origins"
    ;;
  
  staging)
    echo "🧪 Staging deployment mode"
    echo "   - Performance monitoring enabled"
    echo "   - Error reporting to staging Sentry"
    echo "   - Limited CORS origins"
    ;;
  
  production)
    echo "🚀 Production deployment mode"
    echo "   - Full optimization"
    echo "   - Error reporting to production Sentry"
    echo "   - Strict CORS policy"
    echo "   - Rate limiting: $RATE_LIMIT req/min"
    ;;
  
  *)
    echo "⚠️  Unknown environment: $ENV_NAME"
    ;;
esac

echo ""
echo "1️⃣  Checking database connectivity..."
echo "   Connecting to: $DB_HOST:${DB_PORT:-5432}"
# In real deployment: psql -h $DB_HOST -p $DB_PORT -U $DB_USER -c "SELECT 1;"
sleep 0.5
echo "   ✅ Database connection OK (simulated)"

echo "2️⃣  Running database migrations..."
# In real deployment: npm run db:migrate
sleep 0.5
echo "   ✅ Migrations complete (simulated)"

echo "3️⃣  Building application bundle..."
# In real deployment: npm run build
sleep 1
echo "   ✅ Build complete (simulated)"

echo "4️⃣  Deploying to $ENV_NAME environment..."

# Kubernetes deployment example
if command -v kubectl &> /dev/null; then
  echo "   ☸️  Kubernetes deployment mode"
  echo "   kubectl set env deployment/myapp API_URL=$API_URL"
  echo "   kubectl set env deployment/myapp DB_HOST=$DB_HOST"
  echo "   kubectl rollout status deployment/myapp"
fi

# Docker Compose example
if command -v docker-compose &> /dev/null; then
  echo "   🐳 Docker Compose deployment mode"
  echo "   docker-compose up -d --force-recreate"
fi

sleep 1
echo "   ✅ Deployment complete (simulated)"

echo "5️⃣  Running post-deployment checks..."

# Health check
echo "   🏥 Health check: curl -f $API_URL/health"
sleep 0.5
echo "   ✅ Health check passed (simulated)"

# Smoke tests
echo "   🧪 Smoke tests: curl -f $API_URL/version"
sleep 0.5
echo "   ✅ Smoke tests passed (simulated)"

# Feature-specific checks
if [ "${FEATURE_ANALYTICS:-false}" = "true" ]; then
  echo "   📊 Analytics endpoint check..."
  sleep 0.3
  echo "   ✅ Analytics integration verified (simulated)"
fi

echo ""
echo "=================================================="
echo "✅ Deployment to $ENV_NAME successful!"
echo "🌐 Application available at: $API_URL"
echo "=================================================="

# Deployment metadata
echo ""
echo "📝 Deployment Metadata:"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "   Timestamp:      $TIMESTAMP"
echo "   Environment:    $ENV_NAME"
echo "   Config Source:  Configu CLI (direct)"
echo "   Git Commit:     ${CI_COMMIT_SHA:-local}"
echo "   Git Branch:     ${CI_COMMIT_REF_NAME:-local}"
echo "   Pipeline:       ${CI_PIPELINE_ID:-N/A}"

# Log deployment event
echo ""
echo "📋 Logging deployment event..."
cat <<EOF >> deployment.log
{
  "timestamp": "$TIMESTAMP",
  "environment": "$ENV_NAME",
  "api_url": "$API_URL",
  "db_host": "$DB_HOST",
  "config_source": "configu_cli_direct",
  "commit": "${CI_COMMIT_SHA:-local}",
  "pipeline": "${CI_PIPELINE_ID:-N/A}"
}
EOF
echo "   ✅ Logged to deployment.log"

# Notification example
echo ""
echo "📢 Deployment notification:"
echo "   🎉 $ENV_NAME deployment completed successfully!"
echo "   📍 $API_URL"

# Cleanup
echo ""
echo "🧹 Cleaning up temporary files..."
rm -f config.json values.json 2>/dev/null || true
echo "   ✅ Cleanup complete"

echo ""
echo "🎉 Deployment script completed successfully!"
exit 0
