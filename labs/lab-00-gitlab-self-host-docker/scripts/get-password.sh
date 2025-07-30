#!/bin/bash
# Get GitLab initial root password

echo "🔐 Retrieving GitLab initial root password..."
echo

# Check if GitLab container is running
if ! docker-compose ps gitlab | grep -q "Up"; then
    echo "❌ GitLab container is not running"
    echo "Start it first with: docker-compose up -d"
    exit 1
fi

echo "📋 Initial root password:"
echo "========================"
docker-compose exec gitlab cat /etc/gitlab/initial_root_password | grep "Password:"
echo "========================"
echo
echo "📝 Login instructions:"
echo "1. Open http://localhost in your browser"
echo "2. Username: root"
echo "3. Password: Use the password shown above"
echo "4. Change the password immediately after first login"