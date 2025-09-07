#!/bin/bash

# GitLab Renovate Runner - Bot Account Setup Helper
# This script helps create and configure the renovate-bot account

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITLAB_URL="${GITLAB_URL:-http://localhost:8080}"
BOT_USERNAME="${BOT_USERNAME:-renovate-bot}"
BOT_NAME="${BOT_NAME:-Renovate Bot}"
BOT_EMAIL="${BOT_EMAIL:-renovate-bot@example.local}"

echo -e "${BLUE}🤖 GitLab Renovate Bot Account Setup${NC}"
echo "=================================="
echo

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if GitLab is accessible
check_gitlab_access() {
    log_info "Checking GitLab accessibility..."
    
    if curl -s --connect-timeout 10 "$GITLAB_URL" > /dev/null; then
        log_info "✅ GitLab is accessible at $GITLAB_URL"
    else
        log_error "❌ Cannot access GitLab at $GITLAB_URL"
        log_error "Please ensure GitLab is running and accessible"
        exit 1
    fi
}

# Check if user has admin access
check_admin_access() {
    log_info "Admin access verification required..."
    echo
    echo "To create a bot account, you need:"
    echo "1. GitLab Administrator access"
    echo "2. Ability to create new users"
    echo "3. Access to Admin Area > Users"
    echo
    
    read -p "Do you have GitLab admin access? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Admin access is required to create bot accounts"
        log_info "Please ask your GitLab administrator to:"
        log_info "1. Create user '$BOT_USERNAME'"
        log_info "2. Set email: '$BOT_EMAIL'"
        log_info "3. Set name: '$BOT_NAME'"
        log_info "4. Assign regular user role"
        exit 0
    fi
}

# Display manual steps for bot account creation
show_manual_steps() {
    echo
    log_info "🔧 Manual Bot Account Creation Steps:"
    echo "======================================"
    echo
    echo "1. Open GitLab Admin Area:"
    echo "   ${GITLAB_URL}/admin"
    echo
    echo "2. Navigate to Users section:"
    echo "   Admin Area → Users → New User"
    echo
    echo "3. Fill in user details:"
    echo "   - Username: ${BOT_USERNAME}"
    echo "   - Name: ${BOT_NAME}"
    echo "   - Email: ${BOT_EMAIL}"
    echo "   - Access Level: Regular"
    echo "   - External: No"
    echo "   - Admin: No"
    echo
    echo "4. Click 'Create user'"
    echo
    echo "5. Set initial password (user will change on first login)"
    echo
    
    read -p "Press Enter when bot account is created..."
}

# Verify bot account exists
verify_bot_account() {
    log_info "Verifying bot account creation..."
    
    # This would require admin API access, so we'll just provide verification steps
    echo
    echo "To verify the bot account was created successfully:"
    echo "1. Go to: ${GITLAB_URL}/admin/users"
    echo "2. Search for: ${BOT_USERNAME}"
    echo "3. Verify the account appears in the user list"
    echo
    
    read -p "Can you see the ${BOT_USERNAME} account in the admin user list? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "✅ Bot account verified"
    else
        log_error "❌ Bot account not found. Please check the creation steps."
        exit 1
    fi
}

# Guide for Personal Access Token creation
show_token_creation_steps() {
    echo
    log_info "🔑 Personal Access Token Creation:"
    echo "=================================="
    echo
    echo "Next steps (to be done as the bot user):"
    echo
    echo "1. Login as bot user:"
    echo "   - Go to: ${GITLAB_URL}"
    echo "   - Username: ${BOT_USERNAME}"
    echo "   - Use the password you set during creation"
    echo
    echo "2. Change password (if prompted)"
    echo
    echo "3. Create Personal Access Token:"
    echo "   - Go to: Profile → Preferences → Access Tokens"
    echo "   - Token name: 'Renovate Runner Token'"
    echo "   - Expiration date: Set 1 year from now"
    echo "   - Select scopes:"
    echo "     ✅ api"
    echo "     ✅ read_user" 
    echo "     ✅ read_repository"
    echo "     ✅ write_repository"
    echo "   - Click 'Create personal access token'"
    echo
    echo "4. Copy and save the generated token (starts with 'glpat-')"
    echo
    log_warn "⚠️  Save the token immediately - it won't be shown again!"
}

# Guide for adding bot to projects
show_project_access_steps() {
    echo
    log_info "🏗️  Adding Bot to Projects:"
    echo "=========================="
    echo
    echo "For each project you want Renovate to manage:"
    echo
    echo "1. Go to the project"
    echo "2. Navigate to: Project → Members"
    echo "3. Click 'Invite members'"
    echo "4. Add ${BOT_USERNAME} with:"
    echo "   - Role: Developer (minimum)"
    echo "   - Access expiration: No expiration"
    echo "5. Click 'Invite'"
    echo
    echo "Minimum required permissions:"
    echo "- Developer: Can create merge requests and manage branches"
    echo "- Maintainer: Can create webhooks (if needed)"
    echo
}

# Generate configuration template
generate_config_template() {
    echo
    log_info "📝 Configuration Template:"
    echo "========================="
    echo
    
    cat > renovate-runner-config.env << EOF
# GitLab Renovate Runner Configuration
# Copy these to your CI/CD variables

# Required Variables
RENOVATE_TOKEN=glpat-YOUR_BOT_TOKEN_HERE
GITHUB_COM_TOKEN=ghp_YOUR_GITHUB_TOKEN_HERE

# Optional - Repository Discovery
RENOVATE_AUTODISCOVER_FILTER=group/*
# RENOVATE_AUTODISCOVER_FILTER=*/*  # All repositories

# Optional - Behavior Control
RENOVATE_DRY_RUN=           # Leave empty for live mode, 'full' for dry-run
LOG_LEVEL=info              # debug, info, warn, error

# Optional - Performance Tuning
RENOVATE_PR_CONCURRENT_LIMIT=10
RENOVATE_BRANCH_CONCURRENT_LIMIT=10

# Optional - Advanced Settings
RENOVATE_REQUIRE_CONFIG=optional    # required, optional, ignored
EOF

    log_info "✅ Configuration template saved as: renovate-runner-config.env"
    log_info "   Use these values in your GitLab CI/CD variables"
}

# Main execution
main() {
    echo "Starting GitLab Renovate Bot setup process..."
    echo
    
    # Pre-flight checks
    check_gitlab_access
    check_admin_access
    
    # Bot account creation
    show_manual_steps
    verify_bot_account
    
    # Token and access setup
    show_token_creation_steps
    show_project_access_steps
    
    # Configuration generation
    generate_config_template
    
    echo
    log_info "🎉 Bot Account Setup Complete!"
    echo
    echo "Next Steps:"
    echo "1. Save the Personal Access Token in your CI/CD variables"
    echo "2. Add the bot to your target repositories"
    echo "3. Configure and test your Renovate Runner pipeline"
    echo "4. Set up pipeline schedules for automated runs"
    echo
    log_info "For troubleshooting, see: docs/troubleshooting.md"
}

# Run main function
main "$@"