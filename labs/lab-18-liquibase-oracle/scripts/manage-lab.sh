#!/bin/bash

# Lab 18: Liquibase Oracle Management Script
# Comprehensive management script for Oracle Database with Liquibase operations

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
LIQUIBASE_PROPERTIES="$PROJECT_DIR/liquibase.properties"

# Oracle-specific configuration
ORACLE_HOST="${ORACLE_HOST:-oracle}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
ORACLE_SERVICE="${ORACLE_SERVICE:-XEPDB1}"
ORACLE_USERNAME="${ORACLE_USERNAME:-liquibase}"
ORACLE_PASSWORD="${ORACLE_PASSWORD:-liquibase_password}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
print_separator() {
    echo "=================================================="
}

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

# Help function
show_help() {
    cat << 'EOF'
Lab 18: Liquibase Oracle Management Script

USAGE:
    ./manage-lab.sh <command> [options]

COMMANDS:
    setup               - Initialize the Oracle Liquibase environment
    start               - Start all services (Oracle + Liquibase)
    stop                - Stop all services
    restart             - Restart all services
    status              - Show Liquibase status
    update              - Apply database changes
    rollback            - Rollback database changes
    validate            - Validate changelog files
    history             - Show changelog history
    generate-sql        - Generate SQL for pending changes
    clean               - Clean up containers and volumes
    logs                - Show container logs
    oracle-cli          - Connect to Oracle SQL*Plus
    test-connection     - Test Oracle database connection
    run-tests           - Execute test suite (test environment only)
    benchmark           - Run performance benchmarks (test environment)

ROLLBACK OPTIONS:
    -n, --count <n>     - Rollback n changesets
    -t, --tag <tag>     - Rollback to specific tag

CONTEXT OPTIONS:
    -c, --context <ctx> - Run with specific context (development, test, production)

EXAMPLES:
    ./manage-lab.sh setup                    # Initialize environment
    ./manage-lab.sh update -c development    # Update with dev context
    ./manage-lab.sh rollback -n 3            # Rollback 3 changesets
    ./manage-lab.sh generate-sql -c test     # Generate SQL for test context
    ./manage-lab.sh oracle-cli               # Connect to Oracle CLI
    ./manage-lab.sh run-tests                # Run test suite

ORACLE INFORMATION:
    This script manages an Oracle Database 21c XE environment with Liquibase.
    The Oracle database supports advanced features like:
    - PL/SQL procedures and packages
    - Sequences and triggers
    - Materialized views
    - Hierarchical queries
    - JSON storage and queries
    - Advanced indexing strategies
    
    Default connection: oracle:1521/XEPDB1
    Default schema: liquibase
EOF
}

# Check requirements
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
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        print_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    if [[ ! -f "$LIQUIBASE_PROPERTIES" ]]; then
        print_error "Liquibase properties file not found: $LIQUIBASE_PROPERTIES"
        exit 1
    fi
    
    print_success "All requirements satisfied"
}

# Wait for Oracle to be ready
wait_for_oracle() {
    print_info "Waiting for Oracle to be ready..."
    
    local max_attempts=60  # Oracle takes longer to start than MySQL
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" exec -T oracle sqlplus -S $ORACLE_USERNAME/$ORACLE_PASSWORD@//localhost:1521/$ORACLE_SERVICE <<< "SELECT 1 FROM DUAL;" &>/dev/null; then
            print_success "Oracle is ready!"
            return 0
        fi
        
        print_info "Attempt $attempt/$max_attempts - Oracle not ready yet..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    print_error "Oracle did not become ready within the timeout period"
    return 1
}

# Setup environment
setup_environment() {
    print_separator
    print_info "Setting up Liquibase Oracle Lab environment..."
    print_separator
    
    check_requirements
    
    print_info "Building custom Liquibase image with Oracle drivers..."
    docker-compose -f "$COMPOSE_FILE" build liquibase
    
    print_info "Starting Oracle Database..."
    docker-compose -f "$COMPOSE_FILE" up -d oracle
    
    wait_for_oracle
    
    print_info "Validating Liquibase configuration..."
    run_liquibase_command validate
    
    print_success "Environment setup completed!"
    print_info "Oracle Enterprise Manager available at: http://localhost:5500/em"
    print_info "Use these credentials: liquibase / liquibase_password"
}

# Start services
start_services() {
    print_info "Starting all services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    wait_for_oracle
    print_success "All services started successfully!"
}

# Stop services
stop_services() {
    print_info "Stopping all services..."
    docker-compose -f "$COMPOSE_FILE" down
    print_success "All services stopped successfully!"
}

# Restart services
restart_services() {
    print_info "Restarting all services..."
    docker-compose -f "$COMPOSE_FILE" restart
    wait_for_oracle
    print_success "Services restarted successfully!"
}

# Run Liquibase command
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

# Show status
show_status() {
    print_info "Showing Liquibase status..."
    run_liquibase_command status --verbose
}

# Update database
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

# Rollback database
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

# Show history
show_history() {
    print_info "Showing changelog history..."
    run_liquibase_command history
}

# Validate changelog
validate_changelog() {
    print_info "Validating changelog files..."
    run_liquibase_command validate
    print_success "Changelog validation passed!"
}

# Generate SQL
generate_sql() {
    local context="$1"
    
    print_info "Generating SQL for pending changes..."
    
    if [ -n "$context" ]; then
        run_liquibase_command update-sql --contexts="$context"
    else
        run_liquibase_command update-sql
    fi
}

# Clean environment
clean_environment() {
    print_warning "This will remove all containers and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleaning up containers and volumes..."
        docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
        docker system prune -f
        print_success "Cleanup completed!"
    else
        print_info "Cleanup cancelled"
    fi
}

# Show logs
show_logs() {
    local service="$1"
    
    if [ -n "$service" ]; then
        print_info "Showing logs for service: $service"
        docker-compose -f "$COMPOSE_FILE" logs -f "$service"
    else
        print_info "Showing logs for all services..."
        docker-compose -f "$COMPOSE_FILE" logs -f
    fi
}

# Oracle CLI
oracle_cli() {
    print_info "Connecting to Oracle SQL*Plus..."
    print_info "Use 'exit;' to quit SQL*Plus"
    docker-compose -f "$COMPOSE_FILE" exec oracle sqlplus $ORACLE_USERNAME/$ORACLE_PASSWORD@//localhost:1521/$ORACLE_SERVICE
}

# Test Oracle connection
test_connection() {
    print_info "Testing Oracle database connection..."
    
    if docker-compose -f "$COMPOSE_FILE" exec -T oracle sqlplus -S $ORACLE_USERNAME/$ORACLE_PASSWORD@//localhost:1521/$ORACLE_SERVICE <<< "
        SELECT 
            'Oracle Database Version: ' || banner as info
        FROM v\$version 
        WHERE banner LIKE 'Oracle%';
        
        SELECT 
            'Current Schema: ' || USER as schema_info
        FROM DUAL;
        
        SELECT 
            'Current Time: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') as time_info
        FROM DUAL;
    "; then
        print_success "Oracle connection test passed!"
    else
        print_error "Oracle connection test failed!"
        return 1
    fi
}

# Run test suite
run_test_suite() {
    print_info "Running Oracle test suite..."
    
    docker-compose -f "$COMPOSE_FILE" exec -T oracle sqlplus -S $ORACLE_USERNAME/$ORACLE_PASSWORD@//localhost:1521/$ORACLE_SERVICE <<< "
        SET SERVEROUTPUT ON SIZE 1000000;
        EXEC run_test_suite();
    "
    
    if [ $? -eq 0 ]; then
        print_success "Test suite completed successfully!"
    else
        print_error "Test suite failed!"
        return 1
    fi
}

# Run performance benchmarks
run_benchmarks() {
    print_info "Running Oracle performance benchmarks..."
    
    docker-compose -f "$COMPOSE_FILE" exec -T oracle sqlplus -S $ORACLE_USERNAME/$ORACLE_PASSWORD@//localhost:1521/$ORACLE_SERVICE <<< "
        SET SERVEROUTPUT ON SIZE 1000000;
        EXEC benchmark_user_queries();
        EXEC benchmark_product_queries();
    "
    
    print_success "Performance benchmarks completed!"
}

# Parse command line arguments
parse_arguments() {
    local context=""
    local count=""
    local tag=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--context)
                context="$2"
                shift 2
                ;;
            -n|--count)
                count="$2"
                shift 2
                ;;
            -t|--tag)
                tag="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Export for use in other functions
    export CONTEXT="$context"
    export ROLLBACK_COUNT="$count"
    export ROLLBACK_TAG="$tag"
}

# Main execution
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    local command="$1"
    shift
    
    # Parse remaining arguments
    parse_arguments "$@"
    
    case $command in
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
            rollback_database "$ROLLBACK_COUNT" "$ROLLBACK_TAG"
            ;;
        validate)
            validate_changelog
            ;;
        history)
            show_history
            ;;
        generate-sql)
            generate_sql "$CONTEXT"
            ;;
        clean)
            clean_environment
            ;;
        logs)
            show_logs "$1"
            ;;
        oracle-cli)
            oracle_cli
            ;;
        test-connection)
            test_connection
            ;;
        run-tests)
            run_test_suite
            ;;
        benchmark)
            run_benchmarks
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"