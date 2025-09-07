#!/bin/bash

# GitLab Renovate Runner - Setup Validation Script
# Validates that all components are properly configured

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration from environment or defaults
GITLAB_URL="${GITLAB_URL:-http://localhost:8080}"
RENOVATE_TOKEN="${RENOVATE_TOKEN:-}"
GITHUB_COM_TOKEN="${GITHUB_COM_TOKEN:-}"
BOT_USERNAME="${BOT_USERNAME:-renovate-bot}"

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

echo -e "${BLUE}🔍 GitLab Renovate Runner Validation${NC}"
echo "====================================="
echo

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((TESTS_FAILED++))
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

# Test GitLab connectivity
test_gitlab_connectivity() {
    echo "🌐 Testing GitLab Connectivity"
    echo "------------------------------"
    
    if curl -s --connect-timeout 10 --max-time 30 "$GITLAB_URL" > /dev/null 2>&1; then
        log_success "GitLab is accessible at $GITLAB_URL"
    else
        log_error "Cannot access GitLab at $GITLAB_URL"
        echo "  Please ensure GitLab is running and accessible"
    fi
    
    # Test API endpoint
    API_URL="${GITLAB_URL}/api/v4"
    if curl -s --connect-timeout 10 --max-time 30 "$API_URL/version" > /dev/null 2>&1; then
        log_success "GitLab API is accessible at $API_URL"
    else
        log_error "Cannot access GitLab API at $API_URL"
    fi
    
    echo
}

# Test bot authentication
test_bot_authentication() {
    echo "🔐 Testing Bot Authentication"
    echo "-----------------------------"
    
    if [[ -z "$RENOVATE_TOKEN" ]]; then
        log_error "RENOVATE_TOKEN environment variable is not set"
        echo "  Please set your GitLab Personal Access Token"
        return
    fi
    
    # Validate token format
    if [[ $RENOVATE_TOKEN =~ ^glpat- ]]; then
        log_success "Token format is valid (GitLab Personal Access Token)"
    else
        log_warn "Token format unusual (expected to start with 'glpat-')"
    fi
    
    # Test API authentication
    API_URL="${GITLAB_URL}/api/v4"
    USER_INFO=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                     --connect-timeout 10 --max-time 30 \
                     "$API_URL/user" 2>/dev/null || echo "error")
    
    if [[ "$USER_INFO" != "error" ]] && echo "$USER_INFO" | grep -q '"username"'; then
        USERNAME=$(echo "$USER_INFO" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        log_success "Bot authentication successful (user: $USERNAME)"
        
        if [[ "$USERNAME" == "$BOT_USERNAME" ]]; then
            log_success "Bot username matches expected value"
        else
            log_warn "Bot username '$USERNAME' differs from expected '$BOT_USERNAME'"
        fi
    else
        log_error "Bot authentication failed"
        echo "  Check token validity and permissions"
        echo "  Required scopes: api, read_user, read_repository, write_repository"
    fi
    
    echo
}

# Test GitHub token (optional but recommended)
test_github_token() {
    echo "🐙 Testing GitHub Token (Optional)"
    echo "---------------------------------"
    
    if [[ -z "$GITHUB_COM_TOKEN" ]]; then
        log_warn "GITHUB_COM_TOKEN not set (optional but recommended)"
        echo "  GitHub token helps with rate limiting for package metadata"
        return
    fi
    
    # Validate GitHub token format
    if [[ $GITHUB_COM_TOKEN =~ ^gh[ps]_ ]]; then
        log_success "GitHub token format is valid"
    else
        log_warn "GitHub token format may be invalid"
    fi
    
    # Test GitHub API access
    GITHUB_USER=$(curl -s --header "Authorization: token $GITHUB_COM_TOKEN" \
                       --connect-timeout 10 --max-time 30 \
                       "https://api.github.com/user" 2>/dev/null || echo "error")
    
    if [[ "$GITHUB_USER" != "error" ]] && echo "$GITHUB_USER" | grep -q '"login"'; then
        LOGIN=$(echo "$GITHUB_USER" | grep -o '"login":"[^"]*"' | cut -d'"' -f4)
        log_success "GitHub token authentication successful (user: $LOGIN)"
    else
        log_warn "GitHub token authentication failed (may impact package metadata fetching)"
    fi
    
    echo
}

# Test repository access
test_repository_access() {
    echo "📚 Testing Repository Access"
    echo "----------------------------"
    
    if [[ -z "$RENOVATE_TOKEN" ]]; then
        log_warn "Cannot test repository access without RENOVATE_TOKEN"
        return
    fi
    
    # Get list of projects bot has access to
    API_URL="${GITLAB_URL}/api/v4"
    PROJECTS=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                    --connect-timeout 10 --max-time 30 \
                    "$API_URL/projects?membership=true&per_page=20" 2>/dev/null || echo "error")
    
    if [[ "$PROJECTS" != "error" ]] && echo "$PROJECTS" | grep -q '"id"'; then
        PROJECT_COUNT=$(echo "$PROJECTS" | grep -o '"id":[0-9]*' | wc -l)
        log_success "Bot has access to $PROJECT_COUNT repositories"
        
        if [[ $PROJECT_COUNT -eq 0 ]]; then
            log_warn "Bot has no repository access - add bot to target repositories"
        elif [[ $PROJECT_COUNT -lt 5 ]]; then
            log_info "Repository access verified:"
            echo "$PROJECTS" | grep -o '"path_with_namespace":"[^"]*"' | head -5 | while read -r line; do
                REPO=$(echo "$line" | cut -d'"' -f4)
                echo "  • $REPO"
            done
        else
            log_info "Bot has access to multiple repositories (showing first 5):"
            echo "$PROJECTS" | grep -o '"path_with_namespace":"[^"]*"' | head -5 | while read -r line; do
                REPO=$(echo "$line" | cut -d'"' -f4)
                echo "  • $REPO"
            done
        fi
    else
        log_error "Cannot retrieve repository list"
        echo "  Check token permissions and bot repository access"
    fi
    
    echo
}

# Test Renovate Docker image
test_renovate_image() {
    echo "🐳 Testing Renovate Docker Image"
    echo "--------------------------------"
    
    # Test if Docker is available
    if ! command -v docker &> /dev/null; then
        log_warn "Docker not available for image testing"
        return
    fi
    
    # Test renovate image pull
    RENOVATE_IMAGE="ghcr.io/renovatebot/renovate:41"
    if docker pull "$RENOVATE_IMAGE" >/dev/null 2>&1; then
        log_success "Renovate Docker image pulled successfully"
        
        # Test running renovate --version
        VERSION_OUTPUT=$(docker run --rm "$RENOVATE_IMAGE" renovate --version 2>/dev/null || echo "error")
        if [[ "$VERSION_OUTPUT" != "error" ]] && echo "$VERSION_OUTPUT" | grep -q "[0-9]"; then
            log_success "Renovate version: $(echo "$VERSION_OUTPUT" | head -1)"
        else
            log_warn "Could not get Renovate version from image"
        fi
    else
        log_error "Failed to pull Renovate Docker image"
        echo "  Check Docker connectivity and image availability"
    fi
    
    echo
}

# Test configuration files
test_configuration_files() {
    echo "📋 Testing Configuration Files"
    echo "------------------------------"
    
    # Test renovate.json
    if [[ -f "renovate.json" ]]; then
        log_success "renovate.json found"
        
        if command -v jq &> /dev/null; then
            if jq empty renovate.json >/dev/null 2>&1; then
                log_success "renovate.json has valid JSON syntax"
            else
                log_error "renovate.json has invalid JSON syntax"
            fi
        else
            log_warn "jq not available for JSON validation"
        fi
    else
        log_warn "renovate.json not found (will use default configuration)"
    fi
    
    # Test config.js
    if [[ -f "config.js" ]]; then
        log_success "config.js found"
        
        if command -v node &> /dev/null; then
            if node -c config.js >/dev/null 2>&1; then
                log_success "config.js has valid JavaScript syntax"
            else
                log_error "config.js has syntax errors"
            fi
        else
            log_warn "Node.js not available for config.js validation"
        fi
    else
        log_info "config.js not found (using JSON configuration)"
    fi
    
    # Test GitLab CI configuration
    if [[ -f ".gitlab-ci.yml" ]]; then
        log_success ".gitlab-ci.yml found"
        
        # Basic YAML syntax check
        if command -v python3 &> /dev/null; then
            if python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))" >/dev/null 2>&1; then
                log_success ".gitlab-ci.yml has valid YAML syntax"
            else
                log_error ".gitlab-ci.yml has invalid YAML syntax"
            fi
        else
            log_warn "Python not available for YAML validation"
        fi
    else
        log_warn ".gitlab-ci.yml not found"
    fi
    
    echo
}

# Test pipeline schedules (requires manual verification)
test_pipeline_schedules() {
    echo "⏰ Pipeline Schedule Verification"
    echo "--------------------------------"
    
    log_info "Pipeline schedules must be verified manually in GitLab:"
    echo "  1. Go to: Project → CI/CD → Schedules"
    echo "  2. Verify schedules are configured (e.g., daily at 2 AM)"
    echo "  3. Check that schedules are active"
    echo "  4. Ensure proper variables are set if needed"
    echo
    
    log_info "Recommended schedule patterns:"
    echo "  • Daily runs: '0 2 * * *' (2 AM daily)"
    echo "  • Security only: '0 */6 * * *' (every 6 hours)"
    echo "  • Weekend major updates: '0 10 * * 0' (Sunday 10 AM)"
    echo
}

# Test template accessibility
test_templates() {
    echo "📄 Testing Template Files"
    echo "-------------------------"
    
    TEMPLATES=(
        "templates/renovate-runner.gitlab-ci.yml"
        "templates/renovate-with-cache.yml"
        "templates/renovate-config-validator.yml"
    )
    
    for template in "${TEMPLATES[@]}"; do
        if [[ -f "$template" ]]; then
            log_success "Template found: $template"
        else
            log_warn "Template missing: $template"
        fi
    done
    
    # Test preset files
    PRESETS=(
        "configs/presets/gitlab-optimized.json"
        "configs/presets/security-focused.json"
    )
    
    for preset in "${PRESETS[@]}"; do
        if [[ -f "$preset" ]]; then
            log_success "Preset found: $preset"
        else
            log_warn "Preset missing: $preset"
        fi
    done
    
    echo
}

# Generate summary report
generate_summary() {
    echo "📊 Validation Summary"
    echo "===================="
    echo
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All critical tests passed! ($TESTS_PASSED/$TOTAL_TESTS)"
    else
        log_error "$TESTS_FAILED tests failed out of $TOTAL_TESTS total tests"
    fi
    
    if [[ $WARNINGS -gt 0 ]]; then
        log_warn "$WARNINGS warnings found"
    fi
    
    echo
    echo "Status Summary:"
    echo "  ✅ Tests Passed: $TESTS_PASSED"
    echo "  ❌ Tests Failed: $TESTS_FAILED"
    echo "  ⚠️  Warnings: $WARNINGS"
    echo
    
    if [[ $TESTS_FAILED -eq 0 && $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}🎉 Setup validation completed successfully!${NC}"
        echo "Your Renovate Runner is ready to use."
    elif [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Setup validation completed with warnings.${NC}"
        echo "Renovate Runner should work, but review warnings above."
    else
        echo -e "${RED}❌ Setup validation found critical issues.${NC}"
        echo "Please resolve the failed tests before proceeding."
    fi
    
    echo
    echo "Next Steps:"
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "  1. Set up pipeline schedules in GitLab"
        echo "  2. Test manual pipeline execution"
        echo "  3. Monitor first automated runs"
    else
        echo "  1. Fix failed tests shown above"
        echo "  2. Re-run this validation script"
        echo "  3. Check docs/troubleshooting.md for help"
    fi
}

# Main execution
main() {
    echo "Starting GitLab Renovate Runner validation..."
    echo
    
    # Run all tests
    test_gitlab_connectivity
    test_bot_authentication
    test_github_token
    test_repository_access
    test_renovate_image
    test_configuration_files
    test_pipeline_schedules
    test_templates
    
    # Generate final report
    generate_summary
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"