#!/bin/bash
# cleanup.sh - GitLab cleanup and removal script

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

# Display warning and confirm
confirm_cleanup() {
    echo "==================================================================="
    echo -e "${RED}⚠️  GitLab Cleanup Warning ⚠️${NC}"
    echo "==================================================================="
    echo
    echo -e "${YELLOW}This script will:${NC}"
    echo "• Stop all GitLab containers"
    echo "• Remove GitLab containers and networks"
    echo "• Delete Docker volumes (all GitLab data)"
    echo "• Remove GitLab data directories"
    echo
    echo -e "${RED}ALL GITLAB DATA WILL BE PERMANENTLY LOST!${NC}"
    echo "This includes:"
    echo "• All repositories and code"
    echo "• All users and projects"
    echo "• All CI/CD pipelines and history"
    echo "• All GitLab configuration"
    echo
    read -p "Are you sure you want to continue? Type 'DELETE' to confirm: " CONFIRM
    
    if [ "$CONFIRM" != "DELETE" ]; then
        print_status "Cleanup cancelled."
        exit 0
    fi
}

# Stop GitLab services
stop_services() {
    print_status "Stopping GitLab services..."
    
    if docker-compose ps -q | grep -q .; then
        docker-compose down
        print_success "GitLab services stopped"
    else
        print_warning "No running services found"
    fi
}

# Remove containers and networks
remove_containers() {
    print_status "Removing containers and networks..."
    
    # Remove containers
    docker-compose down --remove-orphans
    
    # Remove any remaining GitLab containers
    GITLAB_CONTAINERS=$(docker ps -a --filter "name=gitlab" --format "{{.Names}}" || true)
    if [ ! -z "$GITLAB_CONTAINERS" ]; then
        echo "$GITLAB_CONTAINERS" | xargs docker rm -f
        print_status "Removed GitLab containers: $GITLAB_CONTAINERS"
    fi
    
    print_success "Containers and networks removed"
}

# Remove Docker volumes
remove_volumes() {
    print_status "Removing Docker volumes..."
    
    # Remove project volumes
    docker-compose down -v
    
    # Remove any remaining GitLab volumes
    GITLAB_VOLUMES=$(docker volume ls --filter "name=gitlab" --format "{{.Name}}" || true)
    if [ ! -z "$GITLAB_VOLUMES" ]; then
        echo "$GITLAB_VOLUMES" | xargs docker volume rm -f
        print_status "Removed GitLab volumes: $GITLAB_VOLUMES"
    fi
    
    print_success "Docker volumes removed"
}

# Remove data directories
remove_data_directories() {
    print_status "Removing GitLab data directories..."
    
    # Remove /srv/gitlab if it exists
    if [ -d "/srv/gitlab" ]; then
        print_status "Removing /srv/gitlab directory..."
        sudo rm -rf /srv/gitlab
        print_success "Removed /srv/gitlab directory"
    fi
    
    # Remove local config directories
    if [ -d "./config" ]; then
        rm -rf ./config
        print_success "Removed local config directory"
    fi
    
    print_success "Data directories removed"
}

# Clean Docker system
clean_docker_system() {
    print_status "Cleaning Docker system..."
    
    # Remove unused Docker resources
    docker system prune -f
    
    # Remove GitLab images if requested
    echo
    read -p "Remove GitLab Docker images? (y/n): " REMOVE_IMAGES
    
    if [ "$REMOVE_IMAGES" = "y" ] || [ "$REMOVE_IMAGES" = "Y" ]; then
        print_status "Removing GitLab Docker images..."
        
        # Remove GitLab images
        GITLAB_IMAGES=$(docker images --filter "reference=gitlab/*" --format "{{.Repository}}:{{.Tag}}" || true)
        if [ ! -z "$GITLAB_IMAGES" ]; then
            echo "$GITLAB_IMAGES" | xargs docker rmi -f
            print_success "Removed GitLab images"
        fi
    fi
    
    print_success "Docker cleanup completed"
}

# Display final status
display_final_status() {
    echo
    echo "==================================================================="
    echo -e "${GREEN}🧹 GitLab Cleanup Completed${NC}"
    echo "==================================================================="
    echo
    echo -e "${GREEN}✅ All GitLab components have been removed${NC}"
    echo
    echo "What was cleaned up:"
    echo "• GitLab CE containers stopped and removed"
    echo "• GitLab Runner container removed"
    echo "• Docker networks and volumes deleted"
    echo "• GitLab data directories removed"
    echo "• Docker system cleaned"
    echo
    echo -e "${BLUE}To reinstall GitLab:${NC}"
    echo "• Run: ./scripts/setup-gitlab.sh"
    echo "• Or manually: docker-compose up -d"
    echo
    echo -e "${YELLOW}Note: This was a complete cleanup. You'll need to reconfigure everything.${NC}"
}

# Main execution
main() {
    confirm_cleanup
    stop_services
    remove_containers
    remove_volumes
    remove_data_directories
    clean_docker_system
    display_final_status
}

# Check if running in correct directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "Please run this script from the lab-00-gitlab-self-host-docker directory"
    print_status "Usage: cd labs/lab-00-gitlab-self-host-docker && ./scripts/cleanup.sh"
    exit 1
fi

# Run main function
main "$@"