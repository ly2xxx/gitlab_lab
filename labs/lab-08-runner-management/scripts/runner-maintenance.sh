#!/bin/bash
# scripts/runner-maintenance.sh

set -e

# Configuration
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
MAINTENANCE_LOG="/var/log/runner-maintenance.log"
MAX_DISK_USAGE=80
MAX_MEMORY_USAGE=90
MAX_LOG_SIZE="100M"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAINTENANCE_LOG"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Slack notification function
slack_alert() {
    local message="$1"
    local color="${2:-warning}"
    
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\": \"🤖 GitLab Runner Maintenance Alert\",
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"fields\": [{
                        \"title\": \"Message\",
                        \"value\": \"$message\",
                        \"short\": false
                    }, {
                        \"title\": \"Host\",
                        \"value\": \"$(hostname)\",
                        \"short\": true
                    }, {
                        \"title\": \"Timestamp\",
                        \"value\": \"$(date)\",
                        \"short\": true
                    }]
                }]
            }" \
            "$SLACK_WEBHOOK_URL" > /dev/null
    fi
}

# Runner health monitoring
check_runner_health() {
    log_info "Checking GitLab Runner health..."
    
    # Check runner service status
    if ! systemctl is-active --quiet gitlab-runner; then
        log_error "GitLab Runner service is not running"
        log_info "Attempting to restart GitLab Runner..."
        systemctl restart gitlab-runner
        sleep 10
        
        if systemctl is-active --quiet gitlab-runner; then
            log_success "GitLab Runner service restarted successfully"
            slack_alert "GitLab Runner service was restarted on $(hostname)" "good"
        else
            log_error "Failed to restart GitLab Runner service"
            slack_alert "Failed to restart GitLab Runner service on $(hostname)" "danger"
            return 1
        fi
    else
        log_success "GitLab Runner service is running"
    fi
    
    # Check Docker service status
    if ! systemctl is-active --quiet docker; then
        log_error "Docker service is not running"
        log_info "Attempting to restart Docker..."
        systemctl restart docker
        sleep 15
        
        if systemctl is-active --quiet docker; then
            log_success "Docker service restarted successfully"
            slack_alert "Docker service was restarted on $(hostname)" "good"
        else
            log_error "Failed to restart Docker service"
            slack_alert "Failed to restart Docker service on $(hostname)" "danger"
            return 1
        fi
    else
        log_success "Docker service is running"
    fi
    
    # Check runner connectivity
    if ! gitlab-runner verify --log-level error; then
        log_warning "Runner verification failed - may need re-registration"
        slack_alert "Runner verification failed on $(hostname) - manual intervention may be required" "warning"
    else
        log_success "Runner verification passed"
    fi
    
    return 0
}

# System resource monitoring
check_system_resources() {
    log_info "Checking system resources..."
    
    # Check disk space
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    log_info "Disk usage: ${DISK_USAGE}%"
    
    if [ "$DISK_USAGE" -gt "$MAX_DISK_USAGE" ]; then
        log_warning "Disk usage is high: ${DISK_USAGE}%"
        
        # Perform cleanup
        log_info "Performing disk cleanup..."
        cleanup_disk_space
        
        # Re-check disk usage
        NEW_DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
        if [ "$NEW_DISK_USAGE" -lt "$DISK_USAGE" ]; then
            log_success "Disk cleanup completed. Usage reduced from ${DISK_USAGE}% to ${NEW_DISK_USAGE}%"
            slack_alert "Disk cleanup performed on $(hostname). Usage: ${DISK_USAGE}% → ${NEW_DISK_USAGE}%" "good"
        else
            log_warning "Disk cleanup had minimal effect. Usage: ${NEW_DISK_USAGE}%"
            slack_alert "High disk usage on $(hostname): ${NEW_DISK_USAGE}% - manual intervention may be required" "warning"
        fi
    else
        log_success "Disk usage is within acceptable limits: ${DISK_USAGE}%"
    fi
    
    # Check memory usage
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    log_info "Memory usage: ${MEMORY_USAGE}%"
    
    if [ "$MEMORY_USAGE" -gt "$MAX_MEMORY_USAGE" ]; then
        log_warning "Memory usage is high: ${MEMORY_USAGE}%"
        
        # Show top memory consumers
        log_info "Top memory consumers:"
        ps aux --sort=-%mem | head -10 | tee -a "$MAINTENANCE_LOG"
        
        slack_alert "High memory usage on $(hostname): ${MEMORY_USAGE}%" "warning"
    else
        log_success "Memory usage is within acceptable limits: ${MEMORY_USAGE}%"
    fi
    
    # Check load average
    LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    CPU_CORES=$(nproc)
    log_info "Load average: $LOAD_AVERAGE (${CPU_CORES} cores)"
    
    # Check concurrent job count
    RUNNING_JOBS=$(gitlab-runner status 2>/dev/null | grep -c "Running" || echo "0")
    MAX_CONCURRENT=$(grep "concurrent" /etc/gitlab-runner/config.toml | head -1 | awk '{print $3}')
    log_info "Running jobs: $RUNNING_JOBS/$MAX_CONCURRENT"
    
    if [ "$RUNNING_JOBS" -eq "$MAX_CONCURRENT" ]; then
        log_info "Runner at maximum capacity: $RUNNING_JOBS/$MAX_CONCURRENT jobs"
    fi
}

# Disk space cleanup
cleanup_disk_space() {
    log_info "Starting disk cleanup..."
    
    # Clean up Docker
    log_info "Cleaning Docker system..."
    docker system prune -af --filter "until=48h" || log_warning "Docker cleanup failed"
    
    # Clean up old Docker images
    log_info "Removing old Docker images..."
    docker image prune -af --filter "until=168h" || log_warning "Docker image cleanup failed"
    
    # Clean up old build directories
    log_info "Cleaning old builds..."
    find /builds -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    
    # Clean up cache directories
    log_info "Cleaning cache directories..."
    find /cache -type f -mtime +3 -delete 2>/dev/null || true
    
    # Clean up old logs
    log_info "Cleaning old logs..."
    find /var/log -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
    find /var/log -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Clean up temporary files
    log_info "Cleaning temporary files..."
    find /tmp -type f -mtime +1 -delete 2>/dev/null || true
    
    # Clean up APT cache (if Debian/Ubuntu)
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Cleaning APT cache..."
        apt-get clean || log_warning "APT cache cleanup failed"
    fi
    
    # Clean up YUM cache (if RHEL/CentOS)
    if command -v yum >/dev/null 2>&1; then
        log_info "Cleaning YUM cache..."
        yum clean all || log_warning "YUM cache cleanup failed"
    fi
    
    log_success "Disk cleanup completed"
}

# Automated runner updates
update_runner() {
    log_info "Checking for GitLab Runner updates..."
    
    # Check if updates are available
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep gitlab-runner | wc -l)
    elif command -v yum >/dev/null 2>&1; then
        yum check-update gitlab-runner > /dev/null 2>&1
        UPGRADABLE=$?
    else
        log_warning "Unable to check for updates on this system"
        return 0
    fi
    
    if [ "$UPGRADABLE" -gt 0 ]; then
        log_info "GitLab Runner update available. Updating..."
        
        # Stop runner gracefully
        log_info "Gracefully stopping GitLab Runner..."
        gitlab-runner stop
        
        # Perform update
        if command -v apt-get >/dev/null 2>&1; then
            apt-get upgrade gitlab-runner -y
        elif command -v yum >/dev/null 2>&1; then
            yum update gitlab-runner -y
        fi
        
        # Start runner
        log_info "Starting GitLab Runner..."
        gitlab-runner start
        
        # Verify update
        NEW_VERSION=$(gitlab-runner --version | head -1)
        log_success "GitLab Runner updated: $NEW_VERSION"
        slack_alert "GitLab Runner updated on $(hostname): $NEW_VERSION" "good"
    else
        log_info "GitLab Runner is up to date"
    fi
}

# Performance optimization
optimize_performance() {
    log_info "Optimizing runner performance..."
    
    # Optimize Docker daemon if not already done
    if [ ! -f /etc/docker/daemon.json ]; then
        log_info "Configuring Docker daemon optimizations..."
        cat > /etc/docker/daemon.json << EOF
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
EOF
        systemctl restart docker
        log_success "Docker daemon optimized"
    fi
    
    # Optimize system settings
    log_info "Checking system optimizations..."
    
    # Check if optimizations are already applied
    if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf; then
        log_info "Applying system optimizations..."
        cat >> /etc/sysctl.conf << EOF

# GitLab Runner optimizations added $(date)
vm.max_map_count=262144
fs.file-max=2097152
net.core.somaxconn=65535
net.core.netdev_max_backlog=5000
net.ipv4.tcp_max_syn_backlog=4096
EOF
        sysctl -p
        log_success "System optimizations applied"
    else
        log_info "System optimizations already applied"
    fi
    
    # Check and rotate logs
    log_info "Managing log rotation..."
    if [ ! -f /etc/logrotate.d/gitlab-runner ]; then
        cat > /etc/logrotate.d/gitlab-runner << EOF
/var/log/gitlab-runner/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 640 gitlab-runner gitlab-runner
    postrotate
        systemctl reload gitlab-runner
    endscript
}
EOF
        log_success "Log rotation configured"
    fi
}

# Generate health report
generate_health_report() {
    log_info "Generating health report..."
    
    REPORT_FILE="/tmp/runner-health-report-$(date +%Y%m%d-%H%M%S).json"
    
    # Collect system information
    HOSTNAME=$(hostname)
    UPTIME=$(uptime -p)
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    RUNNER_VERSION=$(gitlab-runner --version | head -1)
    DOCKER_VERSION=$(docker --version)
    RUNNING_JOBS=$(gitlab-runner status 2>/dev/null | grep -c "Running" || echo "0")
    
    # Generate JSON report
    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$HOSTNAME",
  "uptime": "$UPTIME",
  "system_metrics": {
    "disk_usage_percent": $DISK_USAGE,
    "memory_usage_percent": $MEMORY_USAGE,
    "load_average": "$LOAD_AVERAGE",
    "running_jobs": $RUNNING_JOBS
  },
  "software_versions": {
    "gitlab_runner": "$RUNNER_VERSION",
    "docker": "$DOCKER_VERSION"
  },
  "service_status": {
    "gitlab_runner": "$(systemctl is-active gitlab-runner)",
    "docker": "$(systemctl is-active docker)",
    "node_exporter": "$(systemctl is-active node_exporter 2>/dev/null || echo inactive)"
  }
}
EOF
    
    log_success "Health report generated: $REPORT_FILE"
    
    # Display summary
    echo ""
    echo "📊 Runner Health Summary:"
    echo "   Hostname: $HOSTNAME"
    echo "   Uptime: $UPTIME"
    echo "   Disk Usage: ${DISK_USAGE}%"
    echo "   Memory Usage: ${MEMORY_USAGE}%"
    echo "   Load Average: $LOAD_AVERAGE"
    echo "   Running Jobs: $RUNNING_JOBS"
    echo "   GitLab Runner: $(systemctl is-active gitlab-runner)"
    echo "   Docker: $(systemctl is-active docker)"
    echo ""
}

# Main execution
main() {
    local action="${1:-health}"
    
    log_info "Starting GitLab Runner maintenance - Action: $action"
    
    case "$action" in
        "health")
            check_runner_health
            check_system_resources
            ;;
        "update")
            update_runner
            ;;
        "optimize")
            optimize_performance
            ;;
        "cleanup")
            cleanup_disk_space
            ;;
        "report")
            generate_health_report
            ;;
        "all")
            check_runner_health
            check_system_resources
            cleanup_disk_space
            optimize_performance
            update_runner
            generate_health_report
            ;;
        *)
            echo "Usage: $0 {health|update|optimize|cleanup|report|all}"
            echo ""
            echo "Available actions:"
            echo "  health   - Check runner and system health"
            echo "  update   - Update GitLab Runner"
            echo "  optimize - Apply performance optimizations"
            echo "  cleanup  - Clean up disk space"
            echo "  report   - Generate health report"
            echo "  all      - Run all maintenance tasks"
            exit 1
            ;;
    esac
    
    log_success "Maintenance completed - Action: $action"
}

# Execute main function with arguments
main "$@"
