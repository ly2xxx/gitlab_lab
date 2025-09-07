#!/bin/bash

# GitLab Renovate Runner - Repository Autodiscovery Test
# Tests repository discovery functionality

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
RENOVATE_AUTODISCOVER_FILTER="${RENOVATE_AUTODISCOVER_FILTER:-*/*}"

echo -e "${BLUE}🔍 Renovate Repository Autodiscovery Test${NC}"
echo "=========================================="
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [[ -z "$RENOVATE_TOKEN" ]]; then
        log_error "RENOVATE_TOKEN environment variable is required"
        echo "Please set your GitLab Personal Access Token:"
        echo "  export RENOVATE_TOKEN=glpat-your-token-here"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warn "jq not found - output will be less formatted"
        JQ_AVAILABLE=false
    else
        JQ_AVAILABLE=true
    fi
    
    log_info "✅ Prerequisites checked"
}

# Test GitLab API connectivity
test_api_connectivity() {
    log_info "Testing GitLab API connectivity..."
    
    API_URL="${GITLAB_URL}/api/v4"
    
    # Test basic API access
    if ! curl -s --connect-timeout 10 --max-time 30 \
              --header "Private-Token: $RENOVATE_TOKEN" \
              "$API_URL/user" > /dev/null 2>&1; then
        log_error "Cannot connect to GitLab API at $API_URL"
        log_error "Check GITLAB_URL and RENOVATE_TOKEN"
        exit 1
    fi
    
    log_info "✅ GitLab API connectivity verified"
}

# Get repository list based on filter
get_repositories() {
    log_info "Discovering repositories with filter: '$RENOVATE_AUTODISCOVER_FILTER'"
    
    API_URL="${GITLAB_URL}/api/v4"
    
    # Get all accessible projects
    PROJECTS_JSON=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                         --connect-timeout 10 --max-time 30 \
                         "$API_URL/projects?membership=true&per_page=100" 2>/dev/null)
    
    if [[ -z "$PROJECTS_JSON" ]] || [[ "$PROJECTS_JSON" == "null" ]]; then
        log_error "Failed to retrieve project list from GitLab API"
        exit 1
    fi
    
    # Filter projects based on autodiscovery filter
    if [[ "$JQ_AVAILABLE" == "true" ]]; then
        # Use jq for precise filtering
        FILTERED_PROJECTS=$(echo "$PROJECTS_JSON" | jq -r '
            .[] | 
            select(.path_with_namespace | match("'"$(echo "$RENOVATE_AUTODISCOVER_FILTER" | sed 's/\*/[^/]*/g')"'")) | 
            .path_with_namespace
        ')
    else
        # Fallback to grep-based filtering
        FILTERED_PROJECTS=$(echo "$PROJECTS_JSON" | \
            grep -o '"path_with_namespace":"[^"]*"' | \
            cut -d'"' -f4 | \
            grep -E "$(echo "$RENOVATE_AUTODISCOVER_FILTER" | sed 's/\*/.*/')")
    fi
    
    echo "$FILTERED_PROJECTS"
}

# Analyze repository details
analyze_repositories() {
    local repositories="$1"
    
    if [[ -z "$repositories" ]]; then
        log_warn "No repositories found matching filter"
        return
    fi
    
    local count
    count=$(echo "$repositories" | wc -l)
    
    log_info "Found $count repositories matching the filter:"
    echo
    
    # Display repositories with details
    echo "$repositories" | while IFS= read -r repo; do
        if [[ -n "$repo" ]]; then
            analyze_single_repository "$repo"
        fi
    done
}

# Analyze a single repository
analyze_single_repository() {
    local repo_path="$1"
    local api_url="${GITLAB_URL}/api/v4"
    
    # Get repository details
    local repo_info
    repo_info=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                     --connect-timeout 10 --max-time 30 \
                     "$api_url/projects/$(echo "$repo_path" | sed 's/\//%2F/g')" 2>/dev/null)
    
    if [[ -z "$repo_info" ]] || ! echo "$repo_info" | grep -q '"id"'; then
        echo "  ❌ $repo_path (cannot access details)"
        return
    fi
    
    # Extract key information
    local has_renovate_config=false
    local default_branch=""
    local last_activity=""
    
    if [[ "$JQ_AVAILABLE" == "true" ]]; then
        default_branch=$(echo "$repo_info" | jq -r '.default_branch // "main"')
        last_activity=$(echo "$repo_info" | jq -r '.last_activity_at // "unknown"')
    else
        default_branch=$(echo "$repo_info" | grep -o '"default_branch":"[^"]*"' | cut -d'"' -f4 || echo "main")
        last_activity=$(echo "$repo_info" | grep -o '"last_activity_at":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    fi
    
    # Check for existing renovate configuration
    local config_files=("renovate.json" ".renovaterc" ".renovaterc.json" "config.js" ".renovaterc.js")
    for config_file in "${config_files[@]}"; do
        local file_check
        file_check=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                          --connect-timeout 5 --max-time 15 \
                          "$api_url/projects/$(echo "$repo_path" | sed 's/\//%2F/g')/repository/files/$(echo "$config_file" | sed 's/\//%2F/g')/raw?ref=$default_branch" 2>/dev/null)
        
        if [[ -n "$file_check" ]] && [[ "$file_check" != *"404"* ]] && [[ "$file_check" != *"error"* ]]; then
            has_renovate_config=true
            break
        fi
    done
    
    # Check for package files that Renovate can manage
    local package_files=("package.json" "requirements.txt" "composer.json" "pom.xml" "Cargo.toml" "go.mod" "Gemfile")
    local detected_languages=()
    
    for pkg_file in "${package_files[@]}"; do
        local file_check
        file_check=$(curl -s --header "Private-Token: $RENOVATE_TOKEN" \
                          --connect-timeout 5 --max-time 15 \
                          "$api_url/projects/$(echo "$repo_path" | sed 's/\//%2F/g')/repository/files/$(echo "$pkg_file" | sed 's/\//%2F/g')/raw?ref=$default_branch" 2>/dev/null)
        
        if [[ -n "$file_check" ]] && [[ "$file_check" != *"404"* ]] && [[ "$file_check" != *"error"* ]]; then
            case "$pkg_file" in
                "package.json") detected_languages+=("Node.js") ;;
                "requirements.txt") detected_languages+=("Python") ;;
                "composer.json") detected_languages+=("PHP") ;;
                "pom.xml") detected_languages+=("Java/Maven") ;;
                "Cargo.toml") detected_languages+=("Rust") ;;
                "go.mod") detected_languages+=("Go") ;;
                "Gemfile") detected_languages+=("Ruby") ;;
            esac
        fi
    done
    
    # Display repository analysis
    echo -n "  📚 $repo_path"
    
    if [[ ${#detected_languages[@]} -gt 0 ]]; then
        echo -n " (${detected_languages[*]})"
    fi
    
    if [[ "$has_renovate_config" == "true" ]]; then
        echo -n " ✅ [Has Renovate config]"
    else
        echo -n " 📝 [Needs config]"
    fi
    
    echo " - Last activity: ${last_activity:0:10}"
}

# Test dry-run simulation
test_dry_run() {
    log_info "Testing dry-run capability..."
    
    # This would typically be done through the GitLab pipeline
    # Here we just verify the setup would work
    
    if command -v docker &> /dev/null; then
        log_info "Docker available - can test dry-run locally"
        
        # Test basic renovate command structure
        local renovate_cmd="docker run --rm -e RENOVATE_TOKEN='$RENOVATE_TOKEN' -e RENOVATE_PLATFORM=gitlab -e RENOVATE_ENDPOINT='${GITLAB_URL}/api/v4' ghcr.io/renovatebot/renovate:41 --dry-run=lookup --autodiscover=true"
        
        echo "Dry-run command would be:"
        echo "$renovate_cmd"
        
        log_info "To test dry-run manually, run the above command"
    else
        log_warn "Docker not available - dry-run testing requires Docker or GitLab pipeline"
    fi
}

# Generate recommendations
generate_recommendations() {
    local repositories="$1"
    
    echo
    log_info "🎯 Recommendations:"
    echo "=================="
    
    if [[ -z "$repositories" ]]; then
        echo "1. ❗ No repositories found with current filter: '$RENOVATE_AUTODISCOVER_FILTER'"
        echo "   Consider adjusting the filter to include your repositories"
        echo
        echo "   Common filter patterns:"
        echo "   • All repositories: '*/*'"
        echo "   • Specific group: 'my-group/*'"
        echo "   • Multiple groups: '{group1/*,group2/*}'"
        echo
        return
    fi
    
    local count
    count=$(echo "$repositories" | wc -l)
    
    echo "1. ✅ Found $count repositories matching your filter"
    
    # Count repositories without Renovate config
    local repos_without_config=0
    while IFS= read -r repo; do
        if [[ -n "$repo" ]] && ! echo "$repo" | grep -q "Has Renovate config"; then
            ((repos_without_config++))
        fi
    done < <(echo "$repositories")
    
    if [[ $repos_without_config -gt 0 ]]; then
        echo
        echo "2. 📝 $repos_without_config repositories need Renovate configuration"
        echo "   Add renovate.json to these repositories to enable updates"
        echo
        echo "   Basic renovate.json template:"
        echo '   {'
        echo '     "$schema": "https://docs.renovatebot.com/renovate-schema.json",'
        echo '     "extends": ["config:recommended"],'
        echo '     "labels": ["renovate", "dependencies"]'
        echo '   }'
    else
        echo "2. ✅ All repositories have Renovate configuration"
    fi
    
    echo
    echo "3. 🚀 Next Steps:"
    echo "   • Set up pipeline schedule in GitLab (daily at 2 AM recommended)"
    echo "   • Test manual pipeline execution first"
    echo "   • Monitor dependency dashboards in target repositories"
    echo "   • Adjust concurrent limits if needed for large numbers of repositories"
    
    if [[ $count -gt 20 ]]; then
        echo
        echo "4. ⚡ Performance Optimization (for $count repositories):"
        echo "   • Consider using high-performance template"
        echo "   • Increase concurrent limits: RENOVATE_PR_CONCURRENT_LIMIT=20"
        echo "   • Enable caching for better performance"
        echo "   • Split into multiple scheduled runs if needed"
    fi
}

# Main execution
main() {
    echo "Starting repository autodiscovery test..."
    echo "Filter: '$RENOVATE_AUTODISCOVER_FILTER'"
    echo "GitLab: $GITLAB_URL"
    echo
    
    # Run checks
    check_prerequisites
    test_api_connectivity
    
    # Get and analyze repositories
    log_info "Performing repository discovery..."
    local repositories
    repositories=$(get_repositories)
    
    analyze_repositories "$repositories"
    test_dry_run
    generate_recommendations "$repositories"
    
    echo
    log_info "🎉 Autodiscovery test completed!"
    
    if [[ -n "$repositories" ]]; then
        echo "Repository discovery is working correctly."
        echo "Renovate Runner will process the repositories shown above."
    else
        echo "⚠️  No repositories found - please check your filter and bot permissions."
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Usage: $0 [options]"
        echo
        echo "Environment Variables:"
        echo "  GITLAB_URL                    GitLab instance URL (default: http://localhost:8080)"
        echo "  RENOVATE_TOKEN               GitLab Personal Access Token (required)"
        echo "  RENOVATE_AUTODISCOVER_FILTER Repository filter pattern (default: */*)"
        echo
        echo "Examples:"
        echo "  $0                                    # Test with default settings"
        echo "  RENOVATE_AUTODISCOVER_FILTER='my-group/*' $0  # Test specific group"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac