#!/bin/bash
# register-runner.sh - GitLab Runner registration script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if GitLab is running
check_gitlab_status() {
    print_status "Checking GitLab status..."
    
    if ! docker-compose ps gitlab | grep -q "Up"; then
        print_error "GitLab is not running. Please start GitLab first with: docker-compose up -d"
        exit 1
    fi
    
    if ! curl -k -s https://localhost >/dev/null 2>&1; then
        print_error "GitLab is not accessible at https://localhost"
        print_status "Please ensure GitLab has finished starting up (may take 5 minutes)"
        exit 1
    fi
    
    print_success "GitLab is running and accessible"
}

# Get registration token
get_registration_token() {
    echo
    echo "==================================================================="
    echo -e "${YELLOW}GitLab Runner Registration${NC}"
    echo "==================================================================="
    echo
    echo "To register the GitLab Runner, you need to get the registration token:"
    echo
    echo "1. Open GitLab in your browser: https://localhost"
    echo "2. Login as root with your password"
    echo "3. Go to: Admin Area → Runners (left sidebar)"
    echo "4. Copy the 'Registration token' from the top of the page"
    echo
    echo -e "${BLUE}The token will look like: ${YELLOW}GR1348941abc123def456...${NC}"
    echo
    read -p "Enter the registration token: " REGISTRATION_TOKEN
    
    if [ -z "$REGISTRATION_TOKEN" ]; then
        print_error "Registration token cannot be empty"
        exit 1
    fi
}

# Register runner
register_runner() {
    print_status "Registering GitLab Runner..."
    
    # Create runner config directory if it doesn't exist
    mkdir -p ./config/runner
    
    # Register the runner non-interactively
    docker-compose exec gitlab-runner gitlab-runner register \
        --non-interactive \
        --url "https://gitlab/" \
        --registration-token "$REGISTRATION_TOKEN" \
        --executor "docker" \
        --docker-image "alpine:latest" \
        --description "Local Docker Runner" \
        --tag-list "docker,local,tutorial" \
        --run-untagged="true" \
        --locked="false" \
        --docker-privileged="true" \
        --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
        --docker-network-mode "lab-00-gitlab-self-host-docker_gitlab-network"
    
    if [ $? -eq 0 ]; then
        print_success "GitLab Runner registered successfully!"
    else
        print_error "Failed to register GitLab Runner"
        exit 1
    fi
}

# Verify runner registration
verify_runner() {
    print_status "Verifying runner registration..."
    
    # List registered runners
    echo
    echo "Registered runners:"
    docker-compose exec gitlab-runner gitlab-runner list
    
    # Check runner status
    sleep 5
    docker-compose exec gitlab-runner gitlab-runner verify
    
    echo
    print_success "Runner verification completed!"
    echo
    echo "You can now:"
    echo "1. Check runner status in GitLab: Admin Area → Runners"
    echo "2. The runner should show as 'online' with a green indicator"
    echo "3. Test the runner by creating a project and adding a .gitlab-ci.yml file"
}

# Create test pipeline
create_test_pipeline() {
    echo
    read -p "Would you like to create a test project to verify the runner? (y/n): " CREATE_TEST
    
    if [ "$CREATE_TEST" = "y" ] || [ "$CREATE_TEST" = "Y" ]; then
        echo
        echo "==================================================================="
        echo -e "${BLUE}Creating Test Project${NC}"
        echo "==================================================================="
        echo
        echo "To test your runner:"
        echo
        echo "1. In GitLab, create a new project:"
        echo "   - Click 'New project' → 'Create blank project'"
        echo "   - Name: 'runner-test'"
        echo "   - Initialize with README: checked"
        echo
        echo "2. Add this .gitlab-ci.yml file to test the runner:"
        echo
        echo "------- Copy this content -------"
        cat << 'EOF'
test_runner:
  script:
    - echo "Hello from GitLab Runner!"
    - echo "Runner: $CI_RUNNER_DESCRIPTION"
    - echo "Docker version:"
    - docker --version
    - echo "Runner tags: $CI_RUNNER_TAGS"
  tags:
    - docker
EOF
        echo "------- End of content -------"
        echo
        echo "3. Commit the file and check CI/CD → Pipelines"
        echo "4. The pipeline should run successfully on your local runner"
    fi
}

# Main execution
main() {
    echo "==================================================================="
    echo -e "${GREEN}🏃 GitLab Runner Registration${NC}"
    echo "==================================================================="
    echo
    
    check_gitlab_status
    get_registration_token
    register_runner
    verify_runner
    create_test_pipeline
    
    echo
    print_success "GitLab Runner setup completed! 🎉"
    echo
    echo "Your GitLab CI/CD environment is now ready for the tutorial labs!"
}

# Check if running in correct directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "Please run this script from the lab-00-gitlab-self-host-docker directory"
    print_status "Usage: cd labs/lab-00-gitlab-self-host-docker && ./scripts/register-runner.sh"
    exit 1
fi

# Run main function
main "$@"