#!/bin/bash
set -e

# Mend Renovate Community Edition Validation Script
# This script validates the complete setup and functionality

echo "🔍 Mend Renovate Community Edition - Validation Script"
echo "======================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation results
VALIDATION_PASSED=0
VALIDATION_TOTAL=0

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((VALIDATION_PASSED++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

increment_total() {
    ((VALIDATION_TOTAL++))
}

# Validation functions

validate_prerequisites() {
    log_info "Checking prerequisites..."
    increment_total
    
    # Check Docker
    if command -v docker &> /dev/null; then
        log_success "Docker is installed: $(docker --version)"
    else
        log_error "Docker is not installed"
        return 1
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        log_success "Docker Compose is available"
    else
        log_error "Docker Compose is not available"
        return 1
    fi
    
    # Check if in correct directory
    if [ -f "docker-compose.yml" ] && [ -f ".env.example" ]; then
        log_success "Running in correct lab directory"
    else
        log_error "Please run this script from the lab-16-mend-renovate directory"
        return 1
    fi
}

validate_environment() {
    log_info "Validating environment configuration..."
    increment_total
    
    if [ -f ".env" ]; then
        log_success ".env file exists"
        
        # Check required variables
        source .env
        
        if [ ! -z "$MEND_RNV_GITLAB_PAT" ] && [ "$MEND_RNV_GITLAB_PAT" != "your_gitlab_pat_here" ]; then
            log_success "GitLab PAT is configured"
        else
            log_error "GitLab PAT is not configured in .env"
            return 1
        fi
        
        if [ ! -z "$GITHUB_COM_TOKEN" ] && [ "$GITHUB_COM_TOKEN" != "your_github_token_here" ]; then
            log_success "GitHub token is configured"
        else
            log_warning "GitHub token is not configured (optional for private registries)"
        fi
        
        if [ "$MEND_RNV_ACCEPT_TOS" = "y" ]; then
            log_success "Terms of Service accepted"
        else
            log_error "Terms of Service not accepted in .env"
            return 1
        fi
        
    else
        log_error ".env file not found. Run setup.sh first."
        return 1
    fi
}

validate_gitlab_connection() {
    log_info "Validating GitLab connection..."
    increment_total
    
    source .env
    
    # Check GitLab API
    if curl -s -f -H "Private-Token: $MEND_RNV_GITLAB_PAT" \
       "$MEND_RNV_ENDPOINT/user" > /dev/null 2>&1; then
        log_success "GitLab API connection successful"
        
        # Get user info
        USER_INFO=$(curl -s -H "Private-Token: $MEND_RNV_GITLAB_PAT" \
                    "$MEND_RNV_ENDPOINT/user")
        USERNAME=$(echo "$USER_INFO" | grep -o '"username":"[^"]*' | cut -d'"' -f4)
        log_info "Connected as user: $USERNAME"
        
    else
        log_error "Cannot connect to GitLab API. Check MEND_RNV_GITLAB_PAT and MEND_RNV_ENDPOINT"
        return 1
    fi
}

validate_docker_services() {
    log_info "Validating Docker services..."
    increment_total
    
    # Check if services are running
    if docker-compose ps | grep -q "renovate-ce.*Up"; then
        log_success "Renovate CE container is running"
        
        # Check container health
        HEALTH_STATUS=$(docker-compose ps --format "table {{.Service}}\t{{.Status}}" | grep renovate-ce | awk '{print $2}')
        log_info "Container status: $HEALTH_STATUS"
        
    else
        log_error "Renovate CE container is not running. Use 'docker-compose up -d' to start."
        return 1
    fi
}

validate_renovate_api() {
    log_info "Validating Renovate API..."
    increment_total
    
    # Health check
    if curl -s -f http://localhost:8090/api/health > /dev/null; then
        HEALTH_RESPONSE=$(curl -s http://localhost:8090/api/health)
        log_success "Renovate API health check passed"
        log_info "Health response: $HEALTH_RESPONSE"
    else
        log_error "Renovate API health check failed"
        log_info "Checking service logs..."
        docker-compose logs --tail=20 renovate-ce
        return 1
    fi
    
    # Admin API (if enabled)
    source .env
    if [ "$MEND_RNV_ADMIN_API_ENABLED" = "true" ]; then
        if curl -s -f -H "X-API-Key: $MEND_RNV_SERVER_API_SECRET" \
           http://localhost:8090/api/admin/info > /dev/null; then
            log_success "Admin API is accessible"
        else
            log_warning "Admin API is not accessible (check MEND_RNV_SERVER_API_SECRET)"
        fi
    fi
}

validate_webhook_config() {
    log_info "Validating webhook configuration..."
    increment_total
    
    source .env
    
    if [ ! -z "$MEND_RNV_WEBHOOK_URL" ]; then
        log_success "Webhook URL is configured: $MEND_RNV_WEBHOOK_URL"
        
        # Test webhook endpoint
        if curl -s -f "$MEND_RNV_WEBHOOK_URL" > /dev/null; then
            log_success "Webhook endpoint is reachable"
        else
            log_warning "Webhook endpoint is not reachable (this is expected if no webhooks are configured yet)"
        fi
    else
        log_warning "Webhook URL not configured (manual webhook setup required)"
    fi
}

validate_sample_project() {
    log_info "Validating sample project..."
    increment_total
    
    if [ -d "sample-project" ]; then
        log_success "Sample project directory exists"
        
        cd sample-project
        
        # Check package.json
        if [ -f "package.json" ]; then
            log_success "package.json exists"
            
            # Validate JSON
            if node -e "require('./package.json')" 2>/dev/null; then
                log_success "package.json is valid JSON"
            else
                log_error "package.json is invalid JSON"
                cd ..
                return 1
            fi
        else
            log_error "package.json not found in sample-project"
            cd ..
            return 1
        fi
        
        # Check renovate.json
        if [ -f "renovate.json" ]; then
            log_success "renovate.json exists"
            
            # Validate Renovate config
            if docker run --rm -v "$(pwd):/tmp/project" renovate/renovate:latest \
               renovate-config-validator /tmp/project/renovate.json >/dev/null 2>&1; then
                log_success "renovate.json configuration is valid"
            else
                log_warning "renovate.json configuration has issues (check with renovate-config-validator)"
            fi
        else
            log_error "renovate.json not found in sample-project"
            cd ..
            return 1
        fi
        
        # Check GitLab CI
        if [ -f ".gitlab-ci.yml" ]; then
            log_success ".gitlab-ci.yml exists"
        else
            log_warning ".gitlab-ci.yml not found (optional)"
        fi
        
        cd ..
    else
        log_error "sample-project directory not found"
        return 1
    fi
}

validate_network_connectivity() {
    log_info "Validating network connectivity..."
    increment_total
    
    # Test npm registry
    if curl -s -f https://registry.npmjs.org/ > /dev/null; then
        log_success "NPM registry is accessible"
    else
        log_error "Cannot reach NPM registry"
        return 1
    fi
    
    # Test GitHub API (for public packages)
    source .env
    if [ ! -z "$GITHUB_COM_TOKEN" ] && [ "$GITHUB_COM_TOKEN" != "your_github_token_here" ]; then
        if curl -s -f -H "Authorization: token $GITHUB_COM_TOKEN" \
           https://api.github.com/user > /dev/null; then
            log_success "GitHub API connection successful"
        else
            log_warning "GitHub API connection failed (check GITHUB_COM_TOKEN)"
        fi
    fi
    
    # Test Renovate's ability to reach configured GitLab
    source .env
    GITLAB_HOST=$(echo "$MEND_RNV_ENDPOINT" | sed 's|/api/v4/||' | sed 's|/$||')
    if curl -s -f "$GITLAB_HOST" > /dev/null; then
        log_success "GitLab instance is reachable from current location"
    else
        log_error "Cannot reach GitLab at $GITLAB_HOST"
        return 1
    fi
}

validate_logs() {
    log_info "Checking recent logs for errors..."
    increment_total
    
    # Check for error patterns in logs
    ERROR_COUNT=$(docker-compose logs renovate-ce 2>/dev/null | grep -i "error\|failed\|exception" | wc -l)
    WARNING_COUNT=$(docker-compose logs renovate-ce 2>/dev/null | grep -i "warn\|warning" | wc -l)
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        log_warning "Found $ERROR_COUNT error messages in logs"
        log_info "Recent errors:"
        docker-compose logs --tail=50 renovate-ce | grep -i "error\|failed\|exception" | tail -5
    else
        log_success "No errors found in recent logs"
    fi
    
    if [ "$WARNING_COUNT" -gt 0 ]; then
        log_info "Found $WARNING_COUNT warning messages (this may be normal)"
    fi
}

run_integration_test() {
    log_info "Running integration test..."
    increment_total
    
    source .env
    
    # Test webhook endpoint with sample payload
    WEBHOOK_PAYLOAD='{
        "object_kind": "push",
        "project": {
            "path_with_namespace": "test/project"
        },
        "commits": [
            {
                "message": "test commit"
            }
        ]
    }'
    
    if curl -s -f -X POST \
       -H "Content-Type: application/json" \
       -H "X-Gitlab-Token: $MEND_RNV_WEBHOOK_SECRET" \
       -d "$WEBHOOK_PAYLOAD" \
       "http://localhost:8090/webhook" > /dev/null; then
        log_success "Webhook endpoint accepts test payload"
    else
        log_warning "Webhook endpoint test failed (this may be expected)"
    fi
}

# Main validation function
run_validation() {
    echo "Starting validation process..."
    echo ""
    
    # Run all validation checks
    validate_prerequisites || true
    validate_environment || true
    validate_gitlab_connection || true
    validate_docker_services || true
    validate_renovate_api || true
    validate_webhook_config || true
    validate_sample_project || true
    validate_network_connectivity || true
    validate_logs || true
    run_integration_test || true
    
    echo ""
    echo "=================================================="
    echo "Validation Summary"
    echo "=================================================="
    echo -e "Passed: ${GREEN}$VALIDATION_PASSED${NC} / $VALIDATION_TOTAL checks"
    
    if [ "$VALIDATION_PASSED" -eq "$VALIDATION_TOTAL" ]; then
        echo -e "${GREEN}🎉 All validations passed! Your Renovate setup is ready.${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Create a test project in GitLab"
        echo "2. Add renovate-bot as a member with Developer permissions"
        echo "3. Push code with outdated dependencies"
        echo "4. Wait for Renovate to create merge requests"
        return 0
    elif [ "$VALIDATION_PASSED" -gt $(( VALIDATION_TOTAL / 2 )) ]; then
        echo -e "${YELLOW}⚠️  Most validations passed. Review warnings above.${NC}"
        return 1
    else
        echo -e "${RED}❌ Multiple validation failures. Please fix the issues above.${NC}"
        return 2
    fi
}

# Handle script interruption
trap 'echo "Validation interrupted"; exit 1' INT

# Run main validation
run_validation "$@"
