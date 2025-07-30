#!/bin/bash
# scripts/setup-enterprise-runners.sh

set -e

# Configuration variables
GITLAB_URL="${GITLAB_URL:-https://gitlab.com/}"
REGISTRATION_TOKEN="${REGISTRATION_TOKEN}"
RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX:-enterprise}"
RUNNER_TAGS="${RUNNER_TAGS:-docker,linux,enterprise}"
CONCURRENT_JOBS="${CONCURRENT_JOBS:-10}"
S3_CACHE_BUCKET="${S3_CACHE_BUCKET:-gitlab-runner-cache}"
S3_CACHE_REGION="${S3_CACHE_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# Validate required variables
if [[ -z "$REGISTRATION_TOKEN" ]]; then
    log_error "REGISTRATION_TOKEN environment variable is required"
    exit 1
fi

log_info "Setting up GitLab Enterprise Runners..."

# Detect OS and set package manager
if [[ -f /etc/debian_version ]]; then
    OS="debian"
    PKG_MANAGER="apt"
elif [[ -f /etc/redhat-release ]]; then
    OS="rhel"
    PKG_MANAGER="yum"
else
    log_error "Unsupported operating system"
    exit 1
fi

log_info "Detected OS: $OS"

# Install GitLab Runner
if [[ "$OS" == "debian" ]]; then
    log_info "Installing GitLab Runner on Debian/Ubuntu..."
    curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
    apt-get update
    apt-get install gitlab-runner -y
elif [[ "$OS" == "rhel" ]]; then
    log_info "Installing GitLab Runner on RHEL/CentOS..."
    curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | bash
    yum install gitlab-runner -y
fi

# Install Docker
log_info "Installing Docker..."
if [[ "$OS" == "debian" ]]; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    usermod -aG docker gitlab-runner
elif [[ "$OS" == "rhel" ]]; then
    yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker gitlab-runner
fi

# Install additional tools
log_info "Installing additional tools..."
if [[ "$OS" == "debian" ]]; then
    apt-get install -y curl jq htop iotop git awscli
elif [[ "$OS" == "rhel" ]]; then
    yum install -y curl jq htop iotop git awscli
fi

# Register GitLab Runner
log_info "Registering GitLab Runner..."
gitlab-runner register \
  --non-interactive \
  --url "$GITLAB_URL" \
  --registration-token "$REGISTRATION_TOKEN" \
  --name "$RUNNER_NAME_PREFIX-$(hostname)" \
  --tag-list "$RUNNER_TAGS" \
  --executor docker \
  --docker-image "alpine:latest" \
  --docker-privileged true \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --docker-volumes "/cache" \
  --docker-volumes "/builds:/builds" \
  --docker-network-mode "bridge" \
  --docker-pull-policy "if-not-present"

# Configure advanced settings
log_info "Configuring advanced runner settings..."
cat > /etc/gitlab-runner/config.toml << EOF
concurrent = $CONCURRENT_JOBS
check_interval = 0
log_level = "info"
log_format = "json"

[session_server]
  session_timeout = 1800

[[runners]]
  name = "$RUNNER_NAME_PREFIX-$(hostname)"
  url = "$GITLAB_URL"
  token = "__GENERATED_TOKEN__"
  executor = "docker"
  
  [runners.custom_build_dir]
    enabled = true
  
  [runners.cache]
    Type = "s3"
    Shared = true
    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      BucketName = "$S3_CACHE_BUCKET"
      BucketLocation = "$S3_CACHE_REGION"
      Insecure = false
  
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock",
      "/cache",
      "/builds:/builds"
    ]
    shm_size = 2147483648  # 2GB shared memory
    network_mode = "bridge"
    pull_policy = "if-not-present"
    
    # Resource limits
    memory = "4g"
    memory_swap = "4g"
    cpus = "2.0"
    
    # Security options
    security_opt = ["apparmor:unconfined"]
    
    # Additional configurations
    [runners.docker.services_limits]
      memory = "1g"
      cpus = "0.5"
      
    # Environment variables
    environment = [
      "DOCKER_DRIVER=overlay2",
      "DOCKER_TLS_CERTDIR=/certs"
    ]
EOF

# Set proper permissions
chown gitlab-runner:gitlab-runner /etc/gitlab-runner/config.toml
chmod 600 /etc/gitlab-runner/config.toml

# Configure system optimizations
log_info "Applying system optimizations..."

# Increase file descriptor limits
cat >> /etc/security/limits.conf << EOF
gitlab-runner soft nofile 65536
gitlab-runner hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF

# Optimize kernel parameters
cat >> /etc/sysctl.conf << EOF
# GitLab Runner optimizations
vm.max_map_count=262144
fs.file-max=2097152
net.core.somaxconn=65535
net.core.netdev_max_backlog=5000
net.ipv4.tcp_max_syn_backlog=4096
EOF

sysctl -p

# Configure Docker daemon optimizations
log_info "Optimizing Docker daemon..."
mkdir -p /etc/docker
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
  "default-runtime": "runc",
  "runtimes": {
    "runc": {
      "path": "/usr/bin/runc"
    }
  },
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true,
  "userland-proxy": false,
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
EOF

# Restart Docker to apply changes
systemctl restart docker

# Start and enable GitLab Runner
log_info "Starting GitLab Runner service..."
systemctl start gitlab-runner
systemctl enable gitlab-runner

# Configure log rotation
log_info "Setting up log rotation..."
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

# Install monitoring agent
log_info "Installing monitoring components..."

# Install Node Exporter for Prometheus
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
chown gitlab-runner:gitlab-runner /usr/local/bin/node_exporter

# Create systemd service for Node Exporter
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=gitlab-runner
Group=gitlab-runner
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Create health check script
log_info "Creating health check script..."
cat > /usr/local/bin/runner-health-check.sh << 'EOF'
#!/bin/bash

# GitLab Runner health check script
set -e

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
}

# Check GitLab Runner service
if ! systemctl is-active --quiet gitlab-runner; then
    log_error "GitLab Runner service is not running"
    exit 1
fi

# Check Docker service
if ! systemctl is-active --quiet docker; then
    log_error "Docker service is not running"
    exit 1
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    log_error "Disk usage is critically high: ${DISK_USAGE}%"
    exit 1
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')
if (( $(echo "$MEMORY_USAGE > 95" | bc -l) )); then
    log_error "Memory usage is critically high: ${MEMORY_USAGE}%"
    exit 1
fi

# Check runner connectivity
if ! gitlab-runner verify 2>/dev/null; then
    log_error "Runner verification failed"
    exit 1
fi

log_info "Health check passed"
EOF

chmod +x /usr/local/bin/runner-health-check.sh

# Setup cron job for health checks
echo "*/5 * * * * /usr/local/bin/runner-health-check.sh >> /var/log/runner-health.log 2>&1" | crontab -u gitlab-runner -

# Create cleanup script
log_info "Creating cleanup automation..."
cat > /usr/local/bin/runner-cleanup.sh << 'EOF'
#!/bin/bash

# GitLab Runner cleanup script
set -e

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

# Clean up old Docker images
log_info "Cleaning up Docker images..."
docker system prune -af --filter "until=168h" # Keep images for 1 week

# Clean up old build directories
log_info "Cleaning up old builds..."
find /builds -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

# Clean up cache directories
log_info "Cleaning up cache..."
find /cache -type f -mtime +3 -delete 2>/dev/null || true

# Rotate logs
log_info "Rotating logs..."
logrotate -f /etc/logrotate.d/gitlab-runner

log_info "Cleanup completed"
EOF

chmod +x /usr/local/bin/runner-cleanup.sh

# Setup daily cleanup cron job
echo "0 2 * * * /usr/local/bin/runner-cleanup.sh >> /var/log/runner-cleanup.log 2>&1" | crontab -u gitlab-runner -

# Verify installation
log_info "Verifying installation..."

# Check services
if systemctl is-active --quiet gitlab-runner; then
    log_success "GitLab Runner service is running"
else
    log_error "GitLab Runner service is not running"
fi

if systemctl is-active --quiet docker; then
    log_success "Docker service is running"
else
    log_error "Docker service is not running"
fi

if systemctl is-active --quiet node_exporter; then
    log_success "Node Exporter is running"
else
    log_warning "Node Exporter is not running"
fi

# Check runner registration
if gitlab-runner list | grep -q "$RUNNER_NAME_PREFIX-$(hostname)"; then
    log_success "Runner is registered successfully"
else
    log_error "Runner registration failed"
fi

log_success "GitLab Enterprise Runner setup completed successfully!"
echo ""
echo "📊 Runner Details:"
echo "   Name: $RUNNER_NAME_PREFIX-$(hostname)"
echo "   Tags: $RUNNER_TAGS"
echo "   Concurrent Jobs: $CONCURRENT_JOBS"
echo "   Cache: S3 ($S3_CACHE_BUCKET)"
echo ""
echo "🔍 Monitoring:"
echo "   Health Check: /usr/local/bin/runner-health-check.sh"
echo "   Node Exporter: http://$(hostname -I | awk '{print $1}'):9100"
echo "   Logs: /var/log/gitlab-runner/"
echo ""
echo "🛠 Maintenance:"
echo "   Cleanup: /usr/local/bin/runner-cleanup.sh"
echo "   Config: /etc/gitlab-runner/config.toml"
echo "   Service: systemctl status gitlab-runner"
echo ""
log_info "Setup completed. Runner is ready for use!"
