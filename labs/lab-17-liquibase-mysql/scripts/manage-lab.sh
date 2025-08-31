#!/bin/bash

# Liquibase MySQL Lab - Setup Script
# This script helps set up and manage the Liquibase MySQL lab environment

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$LAB_DIR/docker-compose.yml"
LIQUIBASE_PROPERTIES="$LAB_DIR/liquibase.properties"

# Default values
DEFAULT_CONTEXT="development"
DEFAULT_ACTION="status"

# Functions
print_info() {
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

print_separator() {
    echo "=================================================="
}

show_help() {
    cat << EOF
Liquibase MySQL Lab Management Script

USAGE:
    $0 [ACTION] [OPTIONS]

ACTIONS:
    setup           - Initialize and start the lab environment
    start           - Start the Docker containers
    stop            - Stop the Docker containers
    restart         - Restart the Docker containers
    status          - Show Liquibase status
    update          - Apply pending database changes
    rollback        - Rollback database changes
    history         - Show changelog history
    validate        - Validate changelog files
    generate-sql    - Generate SQL for pending changes
    clean           - Clean up containers and volumes
    logs            - Show container logs
    shell           - Open MySQL shell
    test            - Run database tests
    reset           - Reset database to clean state
    backup          - Create database backup
    restore         - Restore database from backup

OPTIONS:
    -c, --context CONTEXT    Set Liquibase context (default: $DEFAULT_CONTEXT)
    -n, --count COUNT        Number of changesets for rollback (default: 1)
    -t, --tag TAG            Tag for rollback operations
    -f, --file FILE          Specific changelog file
    -h, --help               Show this help message

EXAMPLES:
    $0 setup                          # Initialize the lab environment
    $0 update -c development          # Apply changes for development context
    $0 rollback -n 3                  # Rollback 3 changesets
    $0 status                         # Show current database status
    $0 generate-sql > changes.sql     # Generate SQL and save to file
    $0 shell                          # Open MySQL command line
    $0 test                           # Run test procedures

EOF
}

check_requirements() {
    print_info "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    if [ ! -f "$LIQUIBASE_PROPERTIES" ]; then
        print_error "Liquibase properties file not found: $LIQUIBASE_PROPERTIES"
        exit 1
    fi
    
    print_success "All requirements satisfied"
}

wait_for_mysql() {
    print_info "Waiting for MySQL to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" exec -T mysql mysql -u liquibase -pliquibase_password -e "SELECT 1" liquibase_demo &>/dev/null; then
            print_success "MySQL is ready!"
            return 0
        fi
        
        print_info "Attempt $attempt/$max_attempts - MySQL not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "MySQL did not become ready within the timeout period"
    return 1
}

setup_environment() {
    print_separator
    print_info "Setting up Liquibase MySQL Lab environment..."
    print_separator
    
    check_requirements
    
    print_info "Starting Docker containers..."
    docker-compose -f "$COMPOSE_FILE" up -d mysql
    
    wait_for_mysql
    
    print_info "Validating Liquibase configuration..."
    run_liquibase_command validate
    
    print_success "Lab environment setup completed!"
    print_info "You can now run: $0 update"
}

start_services() {
    print_info "Starting services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    wait_for_mysql
    print_success "Services started successfully!"
}

stop_services() {
    print_info "Stopping services..."
    docker-compose -f "$COMPOSE_FILE" down
    print_success "Services stopped successfully!"
}

restart_services() {
    print_info "Restarting services..."
    docker-compose -f "$COMPOSE_FILE" restart
    
    wait_for_mysql
    print_success "Services restarted successfully!"
}

run_liquibase_command() {
    local command="$1"
    shift
    local extra_args="$@"
    
    print_info "Running Liquibase command: $command"
    
    docker-compose -f "$COMPOSE_FILE" run --rm liquibase \
        --defaults-file=/liquibase/liquibase.properties \
        $extra_args \
        $command
}

show_status() {
    print_info "Showing Liquibase status..."
    run_liquibase_command status --verbose
}

update_database() {
    local context="$1"
    
    print_info "Updating database with context: $context"
    
    if [ -n "$context" ]; then
        run_liquibase_command update --contexts="$context"
    else
        run_liquibase_command update
    fi
    
    print_success "Database update completed!"
}

rollback_database() {
    local count="$1"
    local tag="$2"
    
    if [ -n "$tag" ]; then
        print_info "Rolling back to tag: $tag"
        run_liquibase_command rollback "$tag"
    elif [ -n "$count" ]; then
        print_info "Rolling back $count changesets"
        run_liquibase_command rollback-count "$count"
    else
        print_error "Please specify either count (-n) or tag (-t) for rollback"
        exit 1
    fi
    
    print_success "Database rollback completed!"
}

show_history() {
    print_info "Showing changelog history..."
    run_liquibase_command history
}

validate_changelog() {
    print_info "Validating changelog files..."
    run_liquibase_command validate
    print_success "Changelog validation passed!"
}

generate_sql() {
    local context="$1"
    
    print_info "Generating SQL for pending changes..."
    
    if [ -n "$context" ]; then
        run_liquibase_command update-sql --contexts="$context"
    else
        run_liquibase_command update-sql
    fi
}

clean_environment() {
    print_warning "This will remove all containers and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleaning up environment..."
        docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
        docker system prune -f
        print_success "Environment cleaned successfully!"
    else
        print_info "Clean operation cancelled"
    fi
}

show_logs() {
    print_info "Showing container logs..."
    docker-compose -f "$COMPOSE_FILE" logs -f
}

open_mysql_shell() {
    print_info "Opening MySQL shell..."
    docker-compose -f "$COMPOSE_FILE" exec mysql mysql -u liquibase -pliquibase_password liquibase_demo
}

run_tests() {
    print_info "Running database tests..."
    
    # Apply test context changes
    update_database "test"
    
    # Run test procedures
    print_info "Executing test validation procedures..."
    docker-compose -f "$COMPOSE_FILE" exec -T mysql mysql -u liquibase -pliquibase_password liquibase_demo << EOF
CALL CleanupTestData();
CALL ResetTestSequences();
SELECT 'Test procedures executed successfully' as result;
EOF
    
    print_success "Tests completed!"
}

reset_database() {
    print_warning "This will reset the database to a clean state!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Resetting database..."
        
        # Drop and recreate database
        docker-compose -f "$COMPOSE_FILE" exec -T mysql mysql -u root -prootpassword << EOF
DROP DATABASE IF EXISTS liquibase_demo;
CREATE DATABASE liquibase_demo;
GRANT ALL PRIVILEGES ON liquibase_demo.* TO 'liquibase'@'%';
FLUSH PRIVILEGES;
EOF
        
        print_success "Database reset completed!"
        print_info "Run '$0 update' to apply changes"
    else
        print_info "Reset operation cancelled"
    fi
}

backup_database() {
    local backup_file="backup-$(date +%Y%m%d-%H%M%S).sql"
    
    print_info "Creating database backup: $backup_file"
    
    docker-compose -f "$COMPOSE_FILE" exec -T mysql mysqldump \
        -u liquibase -pliquibase_password \
        --single-transaction --routines --triggers \
        liquibase_demo > "$backup_file"
    
    print_success "Database backup saved to: $backup_file"
}

restore_database() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        print_error "Please specify backup file"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    print_warning "This will restore database from: $backup_file"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Restoring database from backup..."
        
        docker-compose -f "$COMPOSE_FILE" exec -T mysql mysql \
            -u liquibase -pliquibase_password liquibase_demo < "$backup_file"
        
        print_success "Database restored successfully!"
    else
        print_info "Restore operation cancelled"
    fi
}

# Main script logic
CONTEXT=""
COUNT=""
TAG=""
FILE=""
BACKUP_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--context)
            CONTEXT="$2"
            shift 2
            ;;
        -n|--count)
            COUNT="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -f|--file)
            FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        setup)
            ACTION="setup"
            shift
            ;;
        start)
            ACTION="start"
            shift
            ;;
        stop)
            ACTION="stop"
            shift
            ;;
        restart)
            ACTION="restart"
            shift
            ;;
        status)
            ACTION="status"
            shift
            ;;
        update)
            ACTION="update"
            shift
            ;;
        rollback)
            ACTION="rollback"
            shift
            ;;
        history)
            ACTION="history"
            shift
            ;;
        validate)
            ACTION="validate"
            shift
            ;;
        generate-sql)
            ACTION="generate-sql"
            shift
            ;;
        clean)
            ACTION="clean"
            shift
            ;;
        logs)
            ACTION="logs"
            shift
            ;;
        shell)
            ACTION="shell"
            shift
            ;;
        test)
            ACTION="test"
            shift
            ;;
        reset)
            ACTION="reset"
            shift
            ;;
        backup)
            ACTION="backup"
            shift
            ;;
        restore)
            ACTION="restore"
            BACKUP_FILE="$2"
            shift 2
            ;;
        *)
            if [ -z "$ACTION" ]; then
                ACTION="$1"
            fi
            shift
            ;;
    esac
done

# Set default action if none provided
if [ -z "$ACTION" ]; then
    ACTION="$DEFAULT_ACTION"
fi

# Set default context if none provided
if [ -z "$CONTEXT" ]; then
    CONTEXT="$DEFAULT_CONTEXT"
fi

# Change to lab directory
cd "$LAB_DIR"

# Execute the requested action
case "$ACTION" in
    setup)
        setup_environment
        ;;
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    update)
        update_database "$CONTEXT"
        ;;
    rollback)
        rollback_database "$COUNT" "$TAG"
        ;;
    history)
        show_history
        ;;
    validate)
        validate_changelog
        ;;
    generate-sql)
        generate_sql "$CONTEXT"
        ;;
    clean)
        clean_environment
        ;;
    logs)
        show_logs
        ;;
    shell)
        open_mysql_shell
        ;;
    test)
        run_tests
        ;;
    reset)
        reset_database
        ;;
    backup)
        backup_database
        ;;
    restore)
        restore_database "$BACKUP_FILE"
        ;;
    *)
        print_error "Unknown action: $ACTION"
        print_info "Run '$0 --help' for available actions"
        exit 1
        ;;
esac
