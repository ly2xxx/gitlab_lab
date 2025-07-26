#!/bin/bash
# GitLab Runner Registration Script
# Automates runner registration with common configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
GITLAB_URL="https://gitlab.com/"
EXECUTOR="docker"
DOCKER_IMAGE="alpine:latest"
RUNNER_NAME=""
RUNNER_TAGS=""
REGISTRATION_TOKEN=""
DOCKER_PRIVILEGED="false"
CONCURRENT="1"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
show_usage() {
    echo "GitLab Runner Registration Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  -t, --token TOKEN        Registration token from GitLab"
    echo ""
    echo "Optional:"
    echo "  -u, --url URL            GitLab instance URL (default: https://gitlab.com/)"
    echo "  -n, --name NAME          Runner name (default: hostname-executor)"
    echo "  -g, --tags TAGS          Runner tags (comma-separated)"
    echo "  -e, --executor EXECUTOR  Executor type (default: docker)"
    echo "  -i, --image IMAGE        Docker image (default: alpine:latest)"
    echo "  -p, --privileged         Enable Docker privileged mode"
    echo "  -c, --concurrent NUM     Number of concurrent jobs (default: 1)"
    echo "  --shell                  Use shell executor"
    echo "  --kubernetes             Use kubernetes executor"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -t glrt-xxx -n my-runner -g docker,linux"
    echo "  $0 -t glrt-xxx --shell -g shell,linux"
    echo "  $0 -t glrt-xxx --kubernetes -g k8s,production"
    echo "  $0 -t glrt-xxx -p -c 4 -g docker,privileged"
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check if gitlab-runner is installed
    if ! command -v gitlab-runner &> /dev/null; then
        log_error "GitLab Runner is not installed. Please install it first."
        exit 1
    fi
    
    # Check if running with appropriate permissions
    if [[ $EUID -ne 0 ]] && [[ "$EXECUTOR" != "shell" ]]; then
        log_warning "Not running as root. Some executors may require sudo."
    fi
    
    # Check Docker availability for Docker executor
    if [[ "$EXECUTOR" == "docker" ]] && ! command -v docker &> /dev/null; then
        log_error "Docker is required for Docker executor but not found."
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# Generate runner name if not provided
generate_runner_name() {
    if [[ -z "$RUNNER_NAME" ]]; then
        HOSTNAME=$(hostname)
        RUNNER_NAME="${HOSTNAME}-${EXECUTOR}"
        log_info "Generated runner name: $RUNNER_NAME"
    fi
}

# Register Docker runner
register_docker_runner() {
    log_info "Registering Docker runner..."
    
    local cmd="gitlab-runner register --non-interactive"
    cmd+=" --url '$GITLAB_URL'"
    cmd+=" --registration-token '$REGISTRATION_TOKEN'"
    cmd+=" --description '$RUNNER_NAME'"
    cmd+=" --executor 'docker'"
    cmd+=" --docker-image '$DOCKER_IMAGE'"
    
    if [[ -n "$RUNNER_TAGS" ]]; then
        cmd+=" --tag-list '$RUNNER_TAGS'"
    fi
    
    if [[ "$DOCKER_PRIVILEGED" == "true" ]]; then
        cmd+=" --docker-privileged"
    fi
    
    # Add common Docker configurations
    cmd+=" --docker-volumes '/var/run/docker.sock:/var/run/docker.sock'"
    cmd+=" --docker-volumes '/cache'"
    
    eval $cmd
}

# Register Shell runner
register_shell_runner() {
    log_info "Registering Shell runner..."
    
    local cmd="gitlab-runner register --non-interactive"
    cmd+=" --url '$GITLAB_URL'"
    cmd+=" --registration-token '$REGISTRATION_TOKEN'"
    cmd+=" --description '$RUNNER_NAME'"
    cmd+=" --executor 'shell'"
    
    if [[ -n "$RUNNER_TAGS" ]]; then
        cmd+=" --tag-list '$RUNNER_TAGS'"
    fi
    
    eval $cmd
}

# Register Kubernetes runner
register_kubernetes_runner() {
    log_info "Registering Kubernetes runner..."
    
    local cmd="gitlab-runner register --non-interactive"
    cmd+=" --url '$GITLAB_URL'"
    cmd+=" --registration-token '$REGISTRATION_TOKEN'"
    cmd+=" --description '$RUNNER_NAME'"
    cmd+=" --executor 'kubernetes'"
    cmd+=" --kubernetes-image '$DOCKER_IMAGE'"
    cmd+=" --kubernetes-namespace 'gitlab-runner'"
    
    if [[ -n "$RUNNER_TAGS" ]]; then
        cmd+=" --tag-list '$RUNNER_TAGS'"
    fi
    
    eval $cmd
}

# Configure concurrent jobs
configure_concurrent() {
    if [[ "$CONCURRENT" != "1" ]]; then
        log_info "Setting concurrent jobs to $CONCURRENT..."
        gitlab-runner update-config --concurrent "$CONCURRENT"
    fi
}

# Verify registration
verify_registration() {
    log_info "Verifying runner registration..."
    
    # List registered runners
    if gitlab-runner list 2>&1 | grep -q "$RUNNER_NAME"; then
        log_success "Runner '$RUNNER_NAME' registered successfully"
    else
        log_error "Runner registration verification failed"
        exit 1
    fi
    
    # Test runner connectivity
    if gitlab-runner verify --name "$RUNNER_NAME" 2>&1 | grep -q "is alive"; then
        log_success "Runner connectivity verified"
    else
        log_warning "Runner connectivity test failed. Check network and token."
    fi
}

# Show configuration summary
show_summary() {
    echo ""
    log_info "Registration Summary:"
    echo "  GitLab URL: $GITLAB_URL"
    echo "  Runner Name: $RUNNER_NAME"
    echo "  Executor: $EXECUTOR"
    echo "  Tags: ${RUNNER_TAGS:-none}"
    echo "  Concurrent Jobs: $CONCURRENT"
    
    if [[ "$EXECUTOR" == "docker" ]]; then
        echo "  Docker Image: $DOCKER_IMAGE"
        echo "  Privileged Mode: $DOCKER_PRIVILEGED"
    fi
    
    echo ""
    log_info "Next steps:"
    echo "  1. Check runner status: gitlab-runner status"
    echo "  2. View configuration: cat /etc/gitlab-runner/config.toml"
    echo "  3. Monitor logs: journalctl -u gitlab-runner -f"
    echo "  4. Test with a simple pipeline in your GitLab project"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--token)
            REGISTRATION_TOKEN="$2"
            shift 2
            ;;
        -u|--url)
            GITLAB_URL="$2"
            shift 2
            ;;
        -n|--name)
            RUNNER_NAME="$2"
            shift 2
            ;;
        -g|--tags)
            RUNNER_TAGS="$2"
            shift 2
            ;;
        -e|--executor)
            EXECUTOR="$2"
            shift 2
            ;;
        -i|--image)
            DOCKER_IMAGE="$2"
            shift 2
            ;;
        -p|--privileged)
            DOCKER_PRIVILEGED="true"
            shift
            ;;
        -c|--concurrent)
            CONCURRENT="$2"
            shift 2
            ;;
        --shell)
            EXECUTOR="shell"
            shift
            ;;
        --kubernetes)
            EXECUTOR="kubernetes"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$REGISTRATION_TOKEN" ]]; then
    log_error "Registration token is required. Use -t or --token option."
    show_usage
    exit 1
fi

# Main execution
main() {
    log_info "Starting GitLab Runner registration..."
    
    validate_prerequisites
    generate_runner_name
    
    # Register based on executor type
    case "$EXECUTOR" in
        "docker")
            register_docker_runner
            ;;
        "shell")
            register_shell_runner
            ;;
        "kubernetes")
            register_kubernetes_runner
            ;;
        *)
            log_error "Unsupported executor: $EXECUTOR"
            exit 1
            ;;
    esac
    
    configure_concurrent
    verify_registration
    show_summary
    
    log_success "GitLab Runner registration completed successfully!"
}

# Run main function
main