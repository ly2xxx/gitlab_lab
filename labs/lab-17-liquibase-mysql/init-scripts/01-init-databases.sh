#!/bin/bash

# MySQL Initialization Script for Liquibase Lab
# This script is automatically executed by MySQL container on first startup

set -e

echo "=================================================="
echo "Initializing MySQL for Liquibase Lab..."
echo "=================================================="

# Create additional databases for different environments
echo "Creating environment-specific databases..."

mysql -u root -p"$MYSQL_ROOT_PASSWORD" << EOF
-- Create test environment database
CREATE DATABASE IF NOT EXISTS liquibase_test;
GRANT ALL PRIVILEGES ON liquibase_test.* TO '$MYSQL_USER'@'%';

-- Create staging environment database  
CREATE DATABASE IF NOT EXISTS liquibase_staging;
GRANT ALL PRIVILEGES ON liquibase_staging.* TO '$MYSQL_USER'@'%';

-- Create production simulation database
CREATE DATABASE IF NOT EXISTS liquibase_prod;
GRANT ALL PRIVILEGES ON liquibase_prod.* TO '$MYSQL_USER'@'%';

-- Create backup database for restore testing
CREATE DATABASE IF NOT EXISTS liquibase_backup;
GRANT ALL PRIVILEGES ON liquibase_backup.* TO '$MYSQL_USER'@'%';

-- Flush privileges
FLUSH PRIVILEGES;

-- Show created databases
SHOW DATABASES;

-- Show grants for liquibase user
SHOW GRANTS FOR '$MYSQL_USER'@'%';
EOF

echo "MySQL initialization completed successfully!"
echo "Available databases:"
echo "  - liquibase_demo (main)"
echo "  - liquibase_test (testing)"
echo "  - liquibase_staging (staging)"  
echo "  - liquibase_prod (production simulation)"
echo "  - liquibase_backup (backup/restore testing)"
echo "=================================================="
