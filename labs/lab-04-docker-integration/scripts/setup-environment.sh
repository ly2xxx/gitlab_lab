#!/bin/bash
# scripts/setup-environment.sh

set -e

echo "Setting up Docker Integration Lab environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose is required but not installed. Aborting." >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Node.js is required but not installed. Aborting." >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "npm is required but not installed. Aborting." >&2; exit 1; }

# Install dependencies
echo "Installing Node.js dependencies..."
npm install

# Build development image
echo "Building development Docker image..."
docker build -f docker/Dockerfile.development -t gitlab-lab-dev:latest .

# Build production image
echo "Building production Docker image..."
docker build -f docker/Dockerfile.production -t gitlab-lab-prod:latest .

# Start development environment
echo "Starting development environment..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Health check
echo "Performing health check..."
curl -f http://localhost:3000/health || {
    echo "Health check failed. Check the logs:"
    docker-compose logs app
    exit 1
}

echo "✅ Environment setup complete!"
echo "🚀 Application: http://localhost:3000"
echo "📊 Grafana: http://localhost:3001 (admin/admin)"
echo "🔍 Prometheus: http://localhost:9090"
echo "📋 API Docs: http://localhost:3000/api/users"
echo "💚 Health Check: http://localhost:3000/health"
echo "📈 Metrics: http://localhost:3000/metrics"

echo "
To run tests:"
echo "  npm test"
echo "
To stop environment:"
echo "  docker-compose down"
echo "
To view logs:"
echo "  docker-compose logs -f"