#!/bin/bash
# GitLab Runner Installation Script
# Supports Ubuntu/Debian, CentOS/RHEL, and macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
        elif [ -f /etc/redhat-release ]; then
            OS="redhat"
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
    log_info "Detected OS: $OS"
}

# Install GitLab Runner on Debian/Ubuntu
install_debian() {
    log_info "Installing GitLab Runner on Debian/Ubuntu..."
    
    # Add GitLab official repository
    curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
    
    # Install GitLab Runner
    sudo apt-get update
    sudo apt-get install -y gitlab-runner
    
    # Start and enable service
    sudo systemctl enable gitlab-runner
    sudo systemctl start gitlab-runner
    
    log_success "GitLab Runner installed successfully on Debian/Ubuntu"
}

# Install GitLab Runner on CentOS/RHEL
install_redhat() {
    log_info "Installing GitLab Runner on CentOS/RHEL..."
    
    # Add GitLab official repository
    curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
    
    # Install GitLab Runner
    sudo yum install -y gitlab-runner
    
    # Start and enable service
    sudo systemctl enable gitlab-runner
    sudo systemctl start gitlab-runner
    
    log_success "GitLab Runner installed successfully on CentOS/RHEL"
}

# Install GitLab Runner on macOS
install_macos() {
    log_info "Installing GitLab Runner on macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is required but not installed. Please install Homebrew first."
        exit 1
    fi
    
    # Install GitLab Runner via Homebrew
    brew install gitlab-runner
    
    # Start the service
    brew services start gitlab-runner
    
    log_success "GitLab Runner installed successfully on macOS"
}

# Install Docker if not present
install_docker() {
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found. Installing Docker..."
        
        case $OS in
            "debian")
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                sudo usermod -aG docker $USER
                sudo usermod -aG docker gitlab-runner
                ;;
            "redhat")
                sudo yum install -y docker
                sudo systemctl enable docker
                sudo systemctl start docker
                sudo usermod -aG docker $USER
                sudo usermod -aG docker gitlab-runner
                ;;
            "macos")
                log_warning "Please install Docker Desktop for Mac manually"
                ;;
        esac
        
        log_success "Docker installation completed"
    else
        log_info "Docker is already installed"
        
        # Add gitlab-runner user to docker group
        if getent group docker > /dev/null 2>&1; then
            sudo usermod -aG docker gitlab-runner || true
        fi
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying GitLab Runner installation..."
    
    # Check if gitlab-runner command is available
    if command -v gitlab-runner &> /dev/null; then
        VERSION=$(gitlab-runner --version | head -n1)
        log_success "GitLab Runner installed: $VERSION"
    else
        log_error "GitLab Runner installation failed"
        exit 1
    fi
    
    # Check service status
    case $OS in
        "debian"|"redhat")
            if systemctl is-active --quiet gitlab-runner; then
                log_success "GitLab Runner service is running"
            else
                log_warning "GitLab Runner service is not running"
                sudo systemctl start gitlab-runner
            fi
            ;;
        "macos")
            if brew services list | grep -q "gitlab-runner.*started"; then
                log_success "GitLab Runner service is running"
            else
                log_warning "GitLab Runner service may not be running"
            fi
            ;;
    esac
}

# Main installation function
main() {
    log_info "Starting GitLab Runner installation..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. This is not recommended for production."
    fi
    
    # Detect OS
    detect_os
    
    # Install based on OS
    case $OS in
        "debian")
            install_debian
            ;;
        "redhat")
            install_redhat
            ;;
        "macos")
            install_macos
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    # Install Docker if requested
    if [[ "$1" == "--with-docker" ]]; then
        install_docker
    fi
    
    # Verify installation
    verify_installation
    
    log_success "GitLab Runner installation completed!"
    
    # Show next steps
    echo ""
    log_info "Next steps:"
    echo "  1. Register the runner: gitlab-runner register"
    echo "  2. Configure the runner: sudo nano /etc/gitlab-runner/config.toml"
    echo "  3. Check status: gitlab-runner status"
    echo "  4. View logs: sudo journalctl -u gitlab-runner -f"
    echo ""
    log_info "For detailed configuration, see: https://docs.gitlab.com/runner/"
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --with-docker    Also install Docker"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Install GitLab Runner only"
    echo "  $0 --with-docker     # Install GitLab Runner and Docker"
}

# Parse command line arguments
if [[ "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Run main function
main "$@"