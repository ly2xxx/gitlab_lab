#!/bin/bash
# setup-gitlab.sh - Automated GitLab CE setup script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker Desktop first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    fi
    
    # Check system resources
    total_memory=$(docker system info | grep "Total Memory" | awk '{print $3$4}')
    print_status "Available Docker memory: $total_memory"
    
    print_success "Prerequisites check passed!"
}

# Setup environment
setup_environment() {
    print_status "Setting up environment..."
    
    # Set GitLab home directory
    export GITLAB_HOME="/srv/gitlab"
    
    # Create data directories
    print_status "Creating GitLab data directories..."
    sudo mkdir -p $GITLAB_HOME/{config,logs,data}
    
    # Set permissions (Linux/WSL)
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "msys" ]]; then
        sudo chown -R $USER:$USER $GITLAB_HOME
        print_status "Set permissions for GitLab directories"
    fi
    
    # Create SSL directory
    mkdir -p ./config/ssl
    
    # Generate self-signed certificate
    if [ ! -f "./config/ssl/gitlab.crt" ]; then
        print_status "Generating self-signed SSL certificate..."
        openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
            -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=localhost" \
            -keyout ./config/ssl/gitlab.key \
            -out ./config/ssl/gitlab.crt
        print_success "SSL certificate generated"
    fi
    
    print_success "Environment setup completed!"
}

# Start GitLab
start_gitlab() {
    print_status "Starting GitLab CE..."
    
    # Pull latest images
    print_status "Pulling latest Docker images..."
    docker-compose pull
    
    # Start services
    print_status "Starting GitLab services..."
    docker-compose up -d
    
    print_status "GitLab is starting up... This may take 3-5 minutes."
    print_warning "GitLab will be available at: https://localhost"
    
    # Wait for GitLab to be ready
    print_status "Waiting for GitLab to be ready..."
    timeout=300  # 5 minutes
    count=0
    
    while [ $count -lt $timeout ]; do
        if curl -k -s https://localhost >/dev/null 2>&1; then
            print_success "GitLab is ready!"
            break
        fi
        
        echo -n "."
        sleep 10
        count=$((count + 10))
    done
    
    if [ $count -ge $timeout ]; then
        print_error "GitLab startup timed out. Check logs with: docker-compose logs gitlab"
        exit 1
    fi
}

# Display initial setup information
display_setup_info() {
    print_success "GitLab CE installation completed!"
    echo
    echo "==================================================================="
    echo -e "${GREEN}🚀 GitLab is now running!${NC}"
    echo "==================================================================="
    echo
    echo -e "${BLUE}📍 Access URLs:${NC}"
    echo "   Web Interface: https://localhost"
    echo "   Container Registry: https://localhost:5050"
    echo "   SSH Git Access: ssh://git@localhost:2224"
    echo
    echo -e "${BLUE}🔐 Initial Login:${NC}"
    echo "   Username: root"
    echo -e "   Password: ${YELLOW}Run this command to get the password:${NC}"
    echo "   docker-compose exec gitlab cat /etc/gitlab/initial_root_password"
    echo
    echo -e "${BLUE}🏃 GitLab Runner:${NC}"
    echo "   Runner will start automatically after GitLab is ready"
    echo "   Register it using the token from: Admin Area → Runners"
    echo
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "   1. Open https://localhost in your browser"
    echo "   2. Accept the SSL certificate warning"
    echo "   3. Login with root and the initial password"
    echo "   4. Change the root password immediately"
    echo "   5. Register the GitLab Runner"
    echo "   6. Create your first project"
    echo
    echo -e "${BLUE}🛠️ Useful Commands:${NC}"
    echo "   View logs:     docker-compose logs -f gitlab"
    echo "   Stop GitLab:   docker-compose down"
    echo "   Restart:       docker-compose restart"
    echo "   Status:        docker-compose ps"
    echo
    echo -e "${GREEN}Happy coding with GitLab! 🎉${NC}"
}

# Get initial root password
get_root_password() {
    print_status "Retrieving initial root password..."
    echo
    echo "==================================================================="
    echo -e "${YELLOW}Initial Root Password:${NC}"
    docker-compose exec gitlab cat /etc/gitlab/initial_root_password 2>/dev/null | grep "Password:" || {
        print_warning "Could not retrieve password automatically."
        print_status "Try running: docker-compose exec gitlab cat /etc/gitlab/initial_root_password"
    }
    echo "==================================================================="
}

# Main execution
main() {
    echo "==================================================================="
    echo -e "${GREEN}🐳 GitLab CE Self-Hosting Setup${NC}"
    echo "==================================================================="
    echo
    
    check_prerequisites
    setup_environment
    start_gitlab
    display_setup_info
    
    # Wait a bit then try to get password
    sleep 30
    get_root_password
}

# Handle script interruption
cleanup() {
    print_warning "Script interrupted. Cleaning up..."
    docker-compose down 2>/dev/null || true
    exit 1
}

trap cleanup INT TERM

# Check if running in script directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "Please run this script from the lab-00-gitlab-self-host-docker directory"
    print_status "Usage: cd labs/lab-00-gitlab-self-host-docker && ./scripts/setup-gitlab.sh"
    exit 1
fi

# Run main function
main "$@"