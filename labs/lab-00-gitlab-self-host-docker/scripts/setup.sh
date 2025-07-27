#!/bin/bash
# GitLab CE Docker Setup Script

echo "🚀 Starting GitLab CE with Docker..."
echo

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    exit 1
fi

echo "✅ Docker is running"
echo

# Start GitLab
echo "📦 Starting GitLab container..."
docker-compose up -d

if [ $? -eq 0 ]; then
    echo "✅ GitLab container started successfully!"
    echo
    echo "📋 Next steps:"
    echo "1. Wait 3-5 minutes for GitLab to fully start"
    echo "2. Open http://localhost in your browser"
    echo "3. Get the initial root password with:"
    echo "   docker-compose exec gitlab cat /etc/gitlab/initial_root_password"
    echo
    echo "📊 Monitor startup progress:"
    echo "   docker-compose ps        # Check container status"
    echo "   docker-compose logs -f   # View startup logs"
    echo
    echo "🔍 Test when ready:"
    echo "   curl -I http://localhost # Should return HTTP 302"
else
    echo "❌ Failed to start GitLab container"
    echo "Check the error messages above"
    exit 1
fi