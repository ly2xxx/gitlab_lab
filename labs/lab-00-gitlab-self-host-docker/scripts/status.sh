#!/bin/bash
# Check GitLab status

echo "📊 GitLab Status Check"
echo "====================="
echo

echo "🐳 Container Status:"
docker-compose ps
echo

echo "🔍 Connection Test:"
if curl -I http://localhost 2>/dev/null | head -1 | grep -q "302"; then
    echo "✅ GitLab is responding (HTTP 302 redirect to sign-in)"
    echo "🌐 Access GitLab at: http://localhost"
elif curl -I http://localhost 2>/dev/null | head -1 | grep -q "HTTP"; then
    echo "⚠️  GitLab is responding but may still be starting up"
    echo "Response: $(curl -I http://localhost 2>/dev/null | head -1)"
else
    echo "❌ GitLab is not responding yet"
    echo "Wait a few more minutes or check logs with: docker-compose logs gitlab"
fi
echo

echo "🛠️ GitLab Services (if container is running):"
if docker-compose ps gitlab | grep -q "Up"; then
    docker-compose exec gitlab gitlab-ctl status 2>/dev/null || echo "GitLab services are still starting..."
else
    echo "Container is not running"
fi