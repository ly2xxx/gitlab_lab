#!/bin/bash
set -e

# Mend Renovate Community Edition Setup Script
# This script automates the initial setup process

echo "🤖 Mend Renovate Community Edition - Setup Script"
echo "=================================================="

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if GitLab CE is running (from lab-00)
    if ! curl -s http://localhost:8080/api/v4/version &> /dev/null; then
        echo "⚠️  Warning: GitLab CE doesn't seem to be running on localhost:8080"
        echo "   Please start GitLab CE from lab-00-gitlab-self-host-docker first"
    fi
    
    echo "✅ Prerequisites check completed"
}

# Setup environment file
setup_environment() {
    echo "📝 Setting up environment configuration..."
    
    if [ ! -f .env ]; then
        cp .env.example .env
        echo "✅ Created .env file from template"
        echo "⚠️  Please edit .env file with your specific values:"
        echo "   - MEND_RNV_GITLAB_PAT: Your GitLab bot PAT"
        echo "   - GITHUB_COM_TOKEN: Your GitHub token for public packages"
        echo "   - Update other settings as needed"
        
        # Prompt for key values
        read -p "Enter GitLab Personal Access Token (or skip to edit manually): " gitlab_pat
        if [ ! -z "$gitlab_pat" ]; then
            sed -i "s/your_gitlab_pat_here/$gitlab_pat/" .env
            echo "✅ GitLab PAT updated in .env"
        fi
        
        read -p "Enter GitHub token (or skip to edit manually): " github_token
        if [ ! -z "$github_token" ]; then
            sed -i "s/your_github_token_here/$github_token/" .env
            echo "✅ GitHub token updated in .env"
        fi
    else
        echo "✅ .env file already exists"
    fi
}

# Create necessary directories
create_directories() {
    echo "📁 Creating necessary directories..."
    
    mkdir -p renovate/logs
    echo "✅ Created renovate/logs directory"
    
    # Set proper permissions
    chmod 755 renovate/logs
}

# Validate Renovate configuration
validate_config() {
    echo "🔍 Validating Renovate configuration..."
    
    if [ -f "sample-project/renovate.json" ]; then
        echo "📋 Validating renovate.json..."
        # Use Docker to validate the config
        docker run --rm -v "$(pwd)/sample-project:/tmp/project" \
            renovate/renovate:latest \
            renovate-config-validator /tmp/project/renovate.json || true
    fi
    
    echo "✅ Configuration validation completed"
}

# Test Docker setup
test_docker_setup() {
    echo "🐳 Testing Docker setup..."
    
    # Check if we can pull the Renovate image
    echo "📥 Pulling Renovate CE image..."
    docker pull ghcr.io/mend/renovate-ce:8.0.0-full
    
    echo "✅ Docker setup test completed"
}

# Setup sample project
setup_sample_project() {
    echo "📦 Setting up sample project..."
    
    if [ -d "sample-project" ]; then
        echo "✅ Sample project directory exists"
        
        cd sample-project
        
        # Check if package-lock.json exists, create it if not
        if [ ! -f "package-lock.json" ]; then
            echo "📋 Generating package-lock.json..."
            npm install --package-lock-only
        fi
        
        cd ..
        echo "✅ Sample project setup completed"
    else
        echo "❌ Sample project directory not found"
        exit 1
    fi
}

# Start services
start_services() {
    echo "🚀 Starting Mend Renovate Community Edition..."
    
    # Check if services are already running
    if docker-compose ps | grep -q "Up"; then
        echo "⚠️  Services are already running. Restarting..."
        docker-compose restart
    else
        docker-compose up -d
    fi
    
    echo "⏳ Waiting for services to be ready..."
    sleep 10
    
    # Health check
    echo "🏥 Performing health check..."
    for i in {1..30}; do
        if curl -sf http://localhost:8090/api/health > /dev/null 2>&1; then
            echo "✅ Renovate CE is ready!"
            break
        fi
        echo "⏳ Waiting for Renovate CE to be ready... ($i/30)"
        sleep 2
    done
    
    if ! curl -sf http://localhost:8090/api/health > /dev/null 2>&1; then
        echo "❌ Renovate CE health check failed"
        echo "📋 Checking logs..."
        docker-compose logs renovate-ce
        exit 1
    fi
}

# Display next steps
show_next_steps() {
    echo ""
    echo "🎉 Setup completed successfully!"
    echo "=============================="
    echo ""
    echo "Next steps:"
    echo "1. 📝 Review and update .env file with your tokens"
    echo "2. 🤖 Create renovate-bot user in GitLab CE (http://localhost:8080)"
    echo "3. 🔑 Generate Personal Access Token for renovate-bot"
    echo "4. 🔧 Update MEND_RNV_GITLAB_PAT in .env file"
    echo "5. 🔄 Restart services: docker-compose restart"
    echo "6. 📊 Check health: curl http://localhost:8090/api/health"
    echo "7. 🌟 Create test project and enable Renovate"
    echo ""
    echo "Useful commands:"
    echo "- View logs: docker-compose logs -f renovate-ce"
    echo "- Restart: docker-compose restart"
    echo "- Stop: docker-compose down"
    echo "- Admin API: curl -H 'X-API-Key: admin-api-secret' http://localhost:8090/api/admin/info"
    echo ""
    echo "Access points:"
    echo "- GitLab CE: http://localhost:8080"
    echo "- Renovate CE API: http://localhost:8090/api/health"
    echo "- Sample app (when running): http://localhost:3000"
}

# Main execution
main() {
    echo "Starting setup process..."
    
    check_prerequisites
    setup_environment
    create_directories
    setup_sample_project
    validate_config
    test_docker_setup
    
    # Ask if user wants to start services now
    read -p "Start Renovate CE services now? (y/N): " start_now
    if [[ $start_now =~ ^[Yy]$ ]]; then
        start_services
    else
        echo "⏸️  Skipping service startup. Run 'docker-compose up -d' when ready."
    fi
    
    show_next_steps
}

# Handle script interruption
trap 'echo "Setup interrupted"; exit 1' INT

# Run main function
main "$@"
