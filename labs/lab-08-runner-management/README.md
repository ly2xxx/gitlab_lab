# Lab 8: GitLab Runner Management

## Objective
Learn how to install, configure, and manage GitLab Runners for optimal CI/CD performance and scalability.

## Prerequisites
- Completed [Lab 7: Advanced Pipeline Patterns](../lab-07-advanced-patterns/README.md)
- Understanding of GitLab CI/CD fundamentals
- Basic system administration knowledge
- Access to a server or virtual machine for runner installation

## What You'll Learn
- GitLab Runner architecture and types
- Runner installation and registration
- Executor configuration (Docker, Shell, Kubernetes)
- Scaling strategies and auto-scaling
- Runner security and isolation
- Performance optimization
- Monitoring and troubleshooting
- Runner maintenance best practices

## GitLab Runner Overview

### Runner Types
1. **Shared Runners** - Available to all projects
2. **Group Runners** - Available to all projects in a group
3. **Project Runners** - Dedicated to specific projects

### Executor Types
1. **Docker** - Run jobs in Docker containers (recommended)
2. **Shell** - Run jobs directly on the runner machine
3. **Kubernetes** - Run jobs in Kubernetes pods
4. **Docker Machine** - Auto-scale Docker runners
5. **VirtualBox/Parallels** - VM-based execution

## Lab Steps

### Step 1: Runner Installation

#### Linux Installation

```bash
# Download and install GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# Verify installation
gitlab-runner --version
```

#### Windows Installation

```powershell
# Download GitLab Runner binary
Invoke-WebRequest -Uri "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe" -OutFile "gitlab-runner.exe"

# Install as Windows service
.\gitlab-runner.exe install
.\gitlab-runner.exe start
```

#### macOS Installation

```bash
# Using Homebrew
brew install gitlab-runner

# Start the service
brew services start gitlab-runner
```

### Step 2: Runner Registration

#### Basic Registration

```bash
# Interactive registration
sudo gitlab-runner register

# You'll be prompted for:
# - GitLab instance URL (https://gitlab.com/)
# - Registration token (from project/group settings)
# - Runner description
# - Runner tags
# - Executor type
```

#### Automated Registration

```bash
# Non-interactive registration
sudo gitlab-runner register \
  --url "https://gitlab.com/" \
  --registration-token "YOUR_TOKEN" \
  --description "Docker Runner" \
  --tag-list "docker,linux,production" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --docker-privileged
```

### Step 3: Docker Executor Configuration

#### Basic Docker Configuration

```toml
# /etc/gitlab-runner/config.toml
concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-runner"
  url = "https://gitlab.com/"
  token = "YOUR_TOKEN"
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
```

#### Advanced Docker Configuration

```toml
[[runners]]
  name = "advanced-docker-runner"
  url = "https://gitlab.com/"
  token = "YOUR_TOKEN"
  executor = "docker"
  limit = 10
  
  [runners.docker]
    image = "ubuntu:20.04"
    privileged = true
    
    # Resource limits
    memory = "2g"
    memory_swap = "2g"
    memory_reservation = "1g"
    cpus = "1.5"
    
    # Network configuration
    network_mode = "bridge"
    dns = ["8.8.8.8", "8.8.4.4"]
    
    # Volume mounts
    volumes = [
      "/cache",
      "/var/run/docker.sock:/var/run/docker.sock",
      "/builds:/builds"
    ]
    
    # Environment variables
    environment = [
      "CI_SERVER_TLS_CA_FILE=/etc/ssl/certs/ca-certificates.crt"
    ]
    
    # Pull policy
    pull_policy = ["always"]
    
    # Security options
    security_opt = ["apparmor:unconfined"]
    
    # Cleanup
    disable_cache = false
    wait_for_services_timeout = 30
```

### Step 4: Kubernetes Executor Setup

#### Kubernetes Configuration

```toml
[[runners]]
  name = "kubernetes-runner"
  url = "https://gitlab.com/"
  token = "YOUR_TOKEN"
  executor = "kubernetes"
  
  [runners.kubernetes]
    host = "https://kubernetes.default.svc.cluster.local"
    namespace = "gitlab-runner"
    image = "ubuntu:20.04"
    
    # Resource requests and limits
    cpu_request = "100m"
    cpu_limit = "1000m"
    memory_request = "128Mi"
    memory_limit = "1Gi"
    
    # Service account
    service_account = "gitlab-runner"
    
    # Pod annotations
    [runners.kubernetes.pod_annotations]
      "cluster-autoscaler.kubernetes.io/safe-to-evict" = "true"
    
    # Node selector
    [runners.kubernetes.node_selector]
      "node-type" = "ci-runner"
    
    # Tolerations
    [[runners.kubernetes.pod_tolerations]]
      key = "ci-runner"
      operator = "Equal"
      value = "true"
      effect = "NoSchedule"
```

### Step 5: Auto-scaling Configuration

#### Docker Machine Auto-scaling

```toml
[[runners]]
  name = "docker-machine-runner"
  url = "https://gitlab.com/"
  token = "YOUR_TOKEN"
  executor = "docker+machine"
  limit = 20
  
  [runners.machine]
    IdleCount = 2
    IdleTime = 1800
    MaxBuilds = 100
    MachineDriver = "amazonec2"
    MachineName = "gitlab-runner-machine-%s"
    MachineOptions = [
      "amazonec2-access-key=YOUR_ACCESS_KEY",
      "amazonec2-secret-key=YOUR_SECRET_KEY",
      "amazonec2-region=us-east-1",
      "amazonec2-vpc-id=vpc-12345678",
      "amazonec2-subnet-id=subnet-12345678",
      "amazonec2-instance-type=t3.medium",
      "amazonec2-security-group=gitlab-runner"
    ]
  
  [runners.docker]
    image = "alpine:latest"
    privileged = true
```

#### Kubernetes Auto-scaling

```yaml
# gitlab-runner-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: gitlab-runner
  namespace: gitlab-runner
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: gitlab-runner
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Step 6: Security Configuration

#### Runner Isolation

```toml
[[runners]]
  name = "secure-runner"
  url = "https://gitlab.com/"
  token = "YOUR_TOKEN"
  executor = "docker"
  
  # Limit concurrent jobs
  limit = 1
  
  [runners.docker]
    image = "alpine:latest"
    
    # Disable privileged mode for security
    privileged = false
    
    # Use specific user
    user = "1000:1000"
    
    # Limit capabilities
    cap_drop = ["ALL"]
    cap_add = ["SETUID", "SETGID"]
    
    # Security options
    security_opt = [
      "no-new-privileges:true",
      "apparmor:docker-default"
    ]
    
    # Read-only root filesystem
    read_only = true
    
    # Temporary filesystems
    tmpfs = {
      "/tmp" = "rw,noexec,nosuid,size=100m",
      "/var/tmp" = "rw,noexec,nosuid,size=100m"
    }
```

#### Network Security

```toml
[runners.docker]
  # Custom network
  network_mode = "gitlab-runner-network"
  
  # DNS configuration
  dns = ["1.1.1.1", "1.0.0.1"]
  dns_search = ["company.local"]
  
  # Extra hosts
  extra_hosts = [
    "gitlab.company.local:192.168.1.100",
    "registry.company.local:192.168.1.101"
  ]
```

### Step 7: Performance Optimization

#### Caching Strategy

```toml
[[runners]]
  [runners.cache]
    Type = "s3"
    Path = "gitlab-runner-cache"
    Shared = true
    
    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      BucketName = "gitlab-runner-cache"
      BucketLocation = "us-east-1"
      Insecure = false
```

#### Build Directory Optimization

```toml
[runners.custom_build_dir]
  enabled = true

[runners.docker]
  # Use tmpfs for build directory
  volumes = [
    "/cache",
    "tmpfs:/builds:rw,noexec,nosuid,size=1g"
  ]
```

### Step 8: Monitoring and Logging

#### Prometheus Metrics

```toml
# Enable metrics server
listen_address = ":9252"

[[runners]]
  # Enable request metrics
  request_concurrency = 10
```

#### Log Configuration

```bash
# Configure systemd logging
sudo mkdir -p /etc/systemd/system/gitlab-runner.service.d

cat << EOF | sudo tee /etc/systemd/system/gitlab-runner.service.d/logging.conf
[Service]
Environment="LOG_LEVEL=info"
Environment="LOG_FORMAT=json"
EOF

sudo systemctl daemon-reload
sudo systemctl restart gitlab-runner
```

#### Health Check Script

```bash
#!/bin/bash
# runner-health-check.sh

RUNNER_STATUS=$(gitlab-runner status)
RUNNER_PID=$(pgrep gitlab-runner)

if [ -z "$RUNNER_PID" ]; then
    echo "ERROR: GitLab Runner is not running"
    exit 1
fi

# Check runner registration
RUNNER_LIST=$(gitlab-runner list 2>&1)
if echo "$RUNNER_LIST" | grep -q "ERROR"; then
    echo "ERROR: Runner registration issues detected"
    echo "$RUNNER_LIST"
    exit 1
fi

# Check disk space
DISK_USAGE=$(df /var/lib/gitlab-runner | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "WARNING: Disk usage is at ${DISK_USAGE}%"
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2{printf "%.2f", $3*100/$2 }')
if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
    echo "WARNING: Memory usage is at ${MEM_USAGE}%"
fi

echo "GitLab Runner health check passed"
exit 0
```

### Step 9: Troubleshooting

#### Common Issues

**Runner Not Picking Up Jobs**
```bash
# Check runner status
gitlab-runner status

# Verify runner registration
gitlab-runner verify

# Check logs
sudo journalctl -u gitlab-runner -f

# Test connectivity
curl -I https://gitlab.com/
```

**Docker Permission Issues**
```bash
# Add gitlab-runner user to docker group
sudo usermod -aG docker gitlab-runner

# Restart runner service
sudo systemctl restart gitlab-runner

# Verify Docker access
sudo -u gitlab-runner docker ps
```

**Resource Exhaustion**
```bash
# Check system resources
top
df -h
free -h

# Check runner processes
ps aux | grep gitlab-runner

# Monitor Docker containers
docker stats
```

#### Debug Mode

```bash
# Run runner in debug mode
gitlab-runner --debug run

# Check specific runner
gitlab-runner --debug verify --name "runner-name"
```

### Step 10: Maintenance Best Practices

#### Regular Maintenance Tasks

```bash
#!/bin/bash
# runner-maintenance.sh

echo "Starting GitLab Runner maintenance..."

# Update GitLab Runner
echo "Updating GitLab Runner..."
sudo apt-get update
sudo apt-get upgrade gitlab-runner -y

# Clean up Docker
echo "Cleaning up Docker..."
docker system prune -f
docker volume prune -f

# Verify runner health
echo "Verifying runner health..."
gitlab-runner verify --delete

# Restart runner service
echo "Restarting runner service..."
sudo systemctl restart gitlab-runner

# Check runner status
echo "Final status check..."
gitlab-runner status

echo "Maintenance completed!"
```

#### Backup Configuration

```bash
#!/bin/bash
# backup-runner-config.sh

BACKUP_DIR="/backup/gitlab-runner"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configuration
cp /etc/gitlab-runner/config.toml $BACKUP_DIR/config_$DATE.toml

# Backup certificates
if [ -d "/etc/gitlab-runner/certs" ]; then
    cp -r /etc/gitlab-runner/certs $BACKUP_DIR/certs_$DATE
fi

echo "Backup completed: $BACKUP_DIR"
```

## Runner Scaling Strategies

### Small Team (1-10 developers)
- 1-2 shared runners
- Docker executor
- Basic configuration
- Manual scaling

### Medium Team (10-50 developers)
- 3-5 dedicated runners
- Docker + Kubernetes executors
- Auto-scaling enabled
- Resource monitoring

### Large Organization (50+ developers)
- Multiple runner pools
- Kubernetes clusters
- Advanced auto-scaling
- Comprehensive monitoring
- Multi-region deployment

## Security Best Practices

1. **Principle of Least Privilege**
   - Limit runner permissions
   - Use specific user accounts
   - Restrict network access

2. **Isolation**
   - Separate runners for different environments
   - Use containers for job isolation
   - Implement network segmentation

3. **Regular Updates**
   - Keep runner software updated
   - Update base images regularly
   - Monitor security advisories

4. **Monitoring**
   - Log all runner activities
   - Monitor resource usage
   - Set up alerting

## Expected Results

1. **Working Runners**: Successfully installed and registered runners
2. **Job Execution**: Pipelines run efficiently on your runners
3. **Auto-scaling**: Runners scale based on demand
4. **Monitoring**: Health and performance monitoring in place
5. **Security**: Secure runner configuration implemented

## Performance Benchmarks

### Typical Performance Metrics
- **Job Startup Time**: < 30 seconds
- **Resource Utilization**: 70-80% average
- **Cache Hit Rate**: > 80%
- **Job Success Rate**: > 95%

## Next Steps

After mastering runner management:

1. **Advanced Orchestration**: Implement complex multi-runner workflows
2. **Cost Optimization**: Optimize runner costs and resource usage
3. **Enterprise Features**: Explore GitLab Premium/Ultimate features
4. **Custom Executors**: Develop custom executor implementations
5. **Integration**: Integrate with monitoring and alerting systems

## Reference

- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [Runner Executors](https://docs.gitlab.com/runner/executors/)
- [Runner Configuration](https://docs.gitlab.com/runner/configuration/)
- [Auto-scaling](https://docs.gitlab.com/runner/configuration/autoscale.html)