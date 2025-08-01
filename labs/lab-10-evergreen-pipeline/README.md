# Lab 10: Evergreen CI/CD Pipeline Tutorial

## 🎯 Overview

Welcome to Lab 10! This tutorial teaches you how to implement an **Evergreen CI/CD Pipeline** - a comprehensive dependency management system that automatically keeps your Docker-based applications up-to-date by scanning Dockerfiles, checking for newer image versions, and creating merge requests with updates.

Think of it as a simplified version of **Renovate** specifically designed for GitLab repositories and Docker dependencies.

### 🌟 What You'll Learn

- **Evergreen Pipeline Concepts**: Understanding automated dependency management
- **Docker Registry APIs**: Working with Docker Hub and private registries
- **GitLab API Integration**: Automated branch creation and merge requests
- **Scheduling Systems**: APScheduler for automated scans
- **YAML Configuration**: Professional configuration management
- **Webhook Integration**: Manual triggers and API endpoints
- **CI/CD Integration**: GitLab pipeline automation
- **Testing Strategies**: Unit, integration, and performance testing

### 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Scheduler     │    │   Scanner Core   │    │   GitLab API    │
│                 │    │                  │    │                 │
│ • APScheduler   │───▶│ • Dockerfile     │───▶│ • Branch Create │
│ • Cron/Interval│    │   Parser         │    │ • File Update   │
│ • Manual Trigger│    │ • Docker Hub API │    │ • Merge Request │
└─────────────────┘    │ • Version Check  │    └─────────────────┘
                       └──────────────────┘
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Webhook API   │    │   Config Manager │    │   Notifications │
│                 │    │                  │    │                 │
│ • Flask Server  │    │ • YAML Parser    │    │ • Slack/Email   │
│ • Health Check  │    │ • Env Variables  │    │ • Status Updates│
│ • Trigger API   │    │ • Validation     │    │ • Error Reports │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📚 GitHub Sources Consulted

This implementation was enhanced using patterns and best practices from the following GitHub repositories:

### Docker Registry & API Patterns
- **[milvus-io/milvus](https://github.com/milvus-io/milvus)** - Docker Hub API integration patterns
- **[airbytehq/airbyte](https://github.com/airbytehq/airbyte)** - Registry API handling and retry logic
- **[HariSekhon/DevOps-Python-tools](https://github.com/HariSekhon/DevOps-Python-tools)** - Docker Hub tag management
- **[apache/libcloud](https://github.com/apache/libcloud)** - Multi-registry support patterns

### Dockerfile Parsing
- **[pantsbuild/pants)](https://github.com/pantsbuild/pants)** - Advanced Dockerfile parsing techniques
- **[webdevops/Dockerfile](https://github.com/webdevops/Dockerfile)** - Multi-stage build parsing
- **[quay/quay](https://github.com/quay/quay)** - Dockerfile validation patterns
- **[basetenlabs/truss](https://github.com/basetenlabs/truss)** - Docker build emulation

### GitLab API Integration
- **[python-gitlab/python-gitlab](https://github.com/python-gitlab/python-gitlab)** - Official python-gitlab library
- **[ansible-collections/community.general](https://github.com/ansible-collections/community.general)** - GitLab module patterns
- **[gitlabform/gitlabform](https://github.com/gitlabform/gitlabform)** - Advanced GitLab API usage
- **[XmirrorSecurity/OpenSCA-cli](https://github.com/XmirrorSecurity/OpenSCA-cli)** - GitLab scanning patterns

### Renovate-Inspired Patterns
- Research conducted on renovate-gitlab configurations from our initial grep-code search:
  - **[serious-scaffold/ss-python](https://github.com/serious-scaffold/ss-python)** - GitLab renovate templates
  - **[whitesource-ft/ws-examples](https://github.com/whitesource-ft/ws-examples)** - Renovate runner usage
  - **[renovatebot/renovate](https://github.com/renovatebot/renovate)** - Core renovate patterns

## 🛠️ Prerequisites

### System Requirements
- **Operating System**: Windows 11, WSL2, or Linux
- **Python**: 3.8+ (recommended: 3.11)
- **Git**: For repository management
- **Docker**: For containerization (optional)
- **GitLab Account**: With project access and API token

### Development Tools
- **Code Editor**: VS Code, PyCharm, or similar
- **Terminal**: PowerShell (Windows) or Bash (Linux/WSL)
- **Package Manager**: pip (included with Python)

## 🚀 Installation & Setup

### Step 1: Clone and Navigate to Lab

```bash
# Clone the repository (if not already done)
git clone https://github.com/ly2xxx/gitlab_lab.git
cd gitlab_lab/labs/lab-10-evergreen-pipeline

# Switch to the feature branch
git checkout feature/lab-10-evergreen-pipeline
```

### Step 2: Python Environment Setup

#### Option A: Using Virtual Environment (Recommended)

**Windows (PowerShell):**
```powershell
# Create virtual environment
python -m venv evergreen-env

# Activate virtual environment
.\evergreen-env\Scripts\Activate.ps1

# If execution policy error, run:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

**Linux/WSL/macOS:**
```bash
# Create virtual environment
python3 -m venv evergreen-env

# Activate virtual environment
source evergreen-env/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

#### Option B: Using System Python
```bash
# Install dependencies globally (not recommended for production)
pip install -r requirements.txt
```

### Step 3: GitLab Configuration

#### 3.1 Create GitLab Access Token

1. **Navigate to GitLab**: Go to your GitLab instance (gitlab.com or self-hosted)
2. **Access Token Settings**: Profile → Settings → Access Tokens
3. **Create Token**:
   - **Name**: `Evergreen Scanner`
   - **Scopes**: Select:
     - ✅ `api` (full API access)
     - ✅ `read_repository` (read repository)
     - ✅ `write_repository` (write repository)
   - **Expiration**: Set appropriate date
4. **Copy Token**: Save the generated token securely

#### 3.2 Configure Project Settings

```bash
# Copy configuration template
cp config.yaml.example config.yaml

# Edit configuration
# Windows: notepad config.yaml
# Linux/WSL: nano config.yaml
```

**Update `config.yaml`:**
```yaml
# GitLab Configuration
gitlab:
  url: "https://gitlab.com"  # or your GitLab instance URL
  access_token: "your_gitlab_access_token_here"  # Token from step 3.1
  project_path: "your-username/your-project"     # Your project path
  timeout: 60
  retries: 3

# Scanner Configuration
scanner:
  branch_prefix: "evergreen/"
  dockerfile_patterns:
    - "Dockerfile*"
    - "*.dockerfile"
    - "docker/Dockerfile*"

# Scheduler Configuration (for automated scans)
scheduler:
  enabled: true
  interval_hours: 6          # Check every 6 hours
  timezone: "UTC"
  run_on_startup: false

# Webhook Configuration (for manual triggers)
webhook:
  enabled: true
  host: "0.0.0.0"
  port: 8080
  secret_token: "your_secure_webhook_secret"

# Logging Configuration
logging:
  level: "INFO"
  console:
    enabled: true
    colored: true
  file:
    enabled: true
    path: "logs/evergreen.log"
```

### Step 4: Test Installation

#### 4.1 Run Unit Tests
```bash
# Run basic tests
python test_scanner.py

# Run enhanced tests
python test_enhanced_scanner.py

# Run with integration tests (requires internet)
python test_enhanced_scanner.py --integration
```

#### 4.2 Test Configuration
```bash
# Test configuration loading
python -c "
from enhanced_evergreen_scheduler import ConfigManager
config = ConfigManager('config.yaml')
print('✅ Configuration loaded successfully')
print(f'GitLab URL: {config.get(\"gitlab\", \"url\")}')
print(f'Project: {config.get(\"gitlab\", \"project_path\")}')
"
```

#### 4.3 Test Docker Hub API
```bash
# Test Docker Hub connectivity
python -c "
from evergreen_scanner import DockerHubAPI
api = DockerHubAPI()
result = api.get_latest_tag('alpine')
print(f'✅ Docker Hub API working: alpine latest = {result}')
"
```

## 🎮 Usage Guide

### Basic Usage: Single Scan

Run a one-time dependency scan:

```bash
# Basic scan with default configuration
python enhanced_evergreen_scheduler.py --once

# Scan with custom configuration
python enhanced_evergreen_scheduler.py --once --config config.yaml

# Scan with debug logging
LOG_LEVEL=DEBUG python enhanced_evergreen_scheduler.py --once
```

### Advanced Usage: Scheduled Scanning

Run the scanner with automatic scheduling:

```bash
# Start scheduler daemon
python enhanced_evergreen_scheduler.py --config config.yaml

# The scanner will:
# 1. Start the scheduler based on config.yaml settings
# 2. Run scans at specified intervals
# 3. Start webhook server for manual triggers
# 4. Provide health check endpoints
```

### Webhook API Usage

When the webhook server is enabled, you can trigger scans manually:

```bash
# Health check
curl http://localhost:8080/health

# Trigger manual scan
curl -X POST http://localhost:8080/trigger \
  -H "X-Webhook-Secret: your_secure_webhook_secret"

# Get status
curl http://localhost:8080/status
```

### Docker Deployment

#### Option 1: Using Docker Compose

```bash
# Build and run with Docker Compose
docker-compose -f sample-project/.gitlab-ci.yml up -d

# View logs
docker-compose logs -f evergreen-scanner

# Stop service
docker-compose down
```

#### Option 2: Manual Docker Build

```bash
# Build image
docker build -t evergreen-scanner:latest .

# Run container
docker run -d \
  --name evergreen-scanner \
  -p 8080:8080 \
  -v $(pwd)/config.yaml:/app/config.yaml:ro \
  -v $(pwd)/logs:/app/logs \
  -e GITLAB_ACCESS_TOKEN=your_token \
  -e GITLAB_PROJECT_PATH=your/project \
  evergreen-scanner:latest
```

## 🔧 Configuration Reference

### Environment Variables

All configuration can be overridden with environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `GITLAB_URL` | GitLab instance URL | `https://gitlab.com` |
| `GITLAB_ACCESS_TOKEN` | API access token | `glpat-xxxxxxxxxxxx` |
| `GITLAB_PROJECT_PATH` | Project path | `username/project` |
| `SCANNER_BRANCH_PREFIX` | Branch prefix for updates | `evergreen/` |
| `SCHEDULER_ENABLED` | Enable scheduling | `true` |
| `SCHEDULER_INTERVAL_HOURS` | Scan interval | `6` |
| `WEBHOOK_ENABLED` | Enable webhook server | `true` |
| `WEBHOOK_PORT` | Webhook server port | `8080` |
| `LOG_LEVEL` | Logging level | `INFO` |

### Advanced Configuration Options

#### Custom Registry Support

```yaml
scanner:
  registries:
    docker_hub:
      enabled: true
      timeout: 30
      retries: 3
    
    custom_registry:
      enabled: true
      url: "registry.example.com"
      username: "registry_user"
      password: "registry_password"
      timeout: 30
```

#### Notification Configuration

```yaml
notifications:
  slack:
    enabled: true
    webhook_url: "https://hooks.slack.com/services/..."
    channel: "#devops"
    
  email:
    enabled: true
    smtp_server: "smtp.gmail.com"
    smtp_port: 587
    username: "alerts@example.com"
    password: "app_password"
    recipients:
      - "team@example.com"
```

## 🧪 Testing Your Setup

### Test 1: Dockerfile Parsing

Create a test Dockerfile:

```dockerfile
# Create: test_dockerfile
FROM python:3.9.18-slim
FROM node:18.17.0-alpine
FROM nginx:1.24.0
```

Test parsing:

```bash
python -c "
from evergreen_scanner import DockerfileParser
with open('test_dockerfile', 'r') as f:
    content = f.read()
images = DockerfileParser.parse_dockerfile(content)
for img in images:
    print(f'Found: {img}')
"
```

### Test 2: Version Checking

```bash
python -c "
from evergreen_scanner import DockerHubAPI
api = DockerHubAPI()
images = ['python', 'node', 'nginx']
for img in images:
    latest = api.get_latest_tag(img)
    print(f'{img}: {latest}')
"
```

### Test 3: GitLab Authentication

```bash
python -c "
from evergreen_scanner import GitLabEvergreenScanner
scanner = GitLabEvergreenScanner(
    'https://gitlab.com',
    'your_token',
    'your/project'
)
if scanner.authenticate():
    print('✅ GitLab authentication successful')
    print(f'Project: {scanner.project.name}')
else:
    print('❌ GitLab authentication failed')
"
```

## 🔄 GitLab CI Integration

### Setup Scheduled Scans

1. **Add CI Variables**:
   - Go to Project → Settings → CI/CD → Variables
   - Add `EVERGREEN_ACCESS_TOKEN` with your GitLab token

2. **Configure Schedule**:
   - Go to Project → CI/CD → Schedules
   - Create new schedule:
     - **Description**: `Evergreen Dependency Scan`
     - **Interval Pattern**: `0 6 * * *` (daily at 6 AM)
     - **Target Branch**: `main`

3. **Pipeline Configuration**:
   - The included `.gitlab-ci.yml` provides:
     - Configuration validation
     - Unit testing
     - Docker Hub API testing
     - Scheduled dependency scanning
     - Docker deployment
     - Notification integration

### Manual Pipeline Triggers

```bash
# Trigger via GitLab API
curl -X POST \
  -F token=your_pipeline_token \
  -F ref=main \
  -F "variables[SCAN_TYPE]=manual" \
  https://gitlab.com/api/v4/projects/PROJECT_ID/trigger/pipeline
```

## 📊 Monitoring & Observability

### Health Checks

```bash
# Check service health
curl http://localhost:8080/health

# Response example:
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "2.0",
  "scheduler_running": true
}
```

### Log Analysis

```bash
# View real-time logs
tail -f logs/evergreen.log

# Search for errors
grep "ERROR" logs/evergreen.log

# View scan results
grep "✅ Scan.*completed" logs/evergreen.log
```

### Metrics Collection

The scanner provides Prometheus-compatible metrics when enabled:

```yaml
metrics:
  enabled: true
  port: 9090
  endpoint: "/metrics"
```

Access metrics:
```bash
curl http://localhost:9090/metrics
```

## 🔒 Security Considerations

### Access Token Security

- **Store tokens securely**: Use environment variables or secrets management
- **Limit token scope**: Only grant necessary permissions
- **Rotate tokens regularly**: Set expiration dates and update periodically
- **Monitor token usage**: Check access logs regularly

### Network Security

- **Webhook secrets**: Always use secure webhook secrets
- **HTTPS only**: Configure TLS for production deployments
- **Firewall rules**: Restrict access to webhook endpoints
- **VPN/Private networks**: Deploy in secure network environments

### Code Security

```bash
# Run security scan
pip install bandit
bandit -r . -f json

# Check dependencies for vulnerabilities  
pip install safety
safety check -r requirements.txt
```

## 🚨 Troubleshooting

### Common Issues

#### 1. GitLab Authentication Fails

**Symptoms**: `❌ GitLab authentication failed`

**Solutions**:
```bash
# Check token permissions
curl -H "PRIVATE-TOKEN: your_token" https://gitlab.com/api/v4/user

# Verify project access
curl -H "PRIVATE-TOKEN: your_token" https://gitlab.com/api/v4/projects/project_id

# Test token in Python
python -c "
import gitlab
gl = gitlab.Gitlab('https://gitlab.com', private_token='your_token')
try:
    gl.auth()
    user = gl.user
    print(f'✅ Authenticated as: {user.username}')
except Exception as e:
    print(f'❌ Auth failed: {e}')
"
```

#### 2. Docker Hub API Timeouts

**Symptoms**: `Failed to fetch tags for python: timeout`

**Solutions**:
```bash
# Test connectivity
curl -v https://registry.hub.docker.com/v2/repositories/python/tags

# Check rate limits
python -c "
import requests
import time
for i in range(5):
    r = requests.get('https://registry.hub.docker.com/v2/repositories/python/tags')
    print(f'Request {i+1}: Status {r.status_code}')
    time.sleep(1)
"

# Increase timeouts in config.yaml
scanner:
  registries:
    docker_hub:
      timeout: 60  # Increase from 30
      retries: 5   # Increase retries
```

#### 3. Permission Denied on Branch Creation

**Symptoms**: `Error creating update branch/MR: 403 Forbidden`

**Solutions**:
- Verify token has `write_repository` scope
- Check if branch protection rules prevent automatic branches
- Ensure user has Developer role or higher in project

#### 4. Scheduler Not Starting

**Symptoms**: `📅 Scheduler disabled in configuration`

**Solutions**:
```yaml
# Enable scheduler in config.yaml
scheduler:
  enabled: true  # Make sure this is true
  interval_hours: 6
  
# Or via environment variable
export SCHEDULER_ENABLED=true
```

#### 5. Import Errors

**Symptoms**: `ModuleNotFoundError: No module named 'gitlab'`

**Solutions**:
```bash
# Reinstall dependencies
pip install -r requirements.txt

# Check virtual environment
which python
which pip

# Verify installation
python -c "import gitlab; print('✅ python-gitlab installed')"
```

### Debug Mode

Enable comprehensive debugging:

```bash
# Set debug environment
export LOG_LEVEL=DEBUG
export PYTHONPATH=$(pwd)

# Run with verbose output
python enhanced_evergreen_scheduler.py --config config.yaml --once
```

### Getting Help

If you encounter issues:

1. **Check logs**: Review `logs/evergreen.log` for detailed error messages
2. **Test components**: Run individual tests to isolate problems
3. **Verify configuration**: Ensure all required fields are set
4. **Check network**: Verify connectivity to GitLab and Docker Hub
5. **Update dependencies**: Ensure all packages are up-to-date

## 📈 Performance Optimization

### Large Repositories

For repositories with many Dockerfiles:

```yaml
scanner:
  max_concurrent_scans: 5  # Limit concurrent processing
  batch_size: 10          # Process in batches
  exclude_patterns:       # Skip unnecessary paths
    - "test/*"
    - "examples/*"
    - "docs/*"
    - ".git/*"
```

### API Rate Limiting

```yaml
scanner:
  registries:
    docker_hub:
      rate_limit_delay: 2.0  # 2 second delay between requests
      max_requests_per_hour: 100
```

### Memory Usage

Monitor memory usage for long-running processes:

```bash
# Monitor Python process
ps aux | grep python
top -p $(pgrep -f enhanced_evergreen_scheduler)

# Use memory profiling
pip install memory_profiler
python -m memory_profiler enhanced_evergreen_scheduler.py --once
```

## 🎯 Next Steps & Advanced Topics

### 1. Custom Registry Support

Extend the scanner to support private registries:

```python
# Add to evergreen_scanner.py
class CustomRegistryAPI:
    def __init__(self, registry_url, username, password):
        self.registry_url = registry_url
        self.auth = (username, password)
        
    def get_latest_tag(self, image_name):
        # Implement custom registry API logic
        pass
```

### 2. Multi-Project Support

Configure the scanner to handle multiple projects:

```yaml
projects:
  - name: "frontend"
    path: "company/frontend"
    branch_prefix: "deps/"
  - name: "backend"  
    path: "company/backend"
    branch_prefix: "evergreen/"
```

### 3. Advanced Notifications

Implement rich notifications with scan details:

```python
# Add to enhanced_evergreen_scheduler.py
class NotificationManager:
    def send_scan_summary(self, scan_result):
        # Send detailed scan results
        pass
```

### 4. Database Integration

Store scan history in a database:

```bash
# Add database dependencies
pip install sqlalchemy psycopg2-binary

# Implement scan history storage
```

### 5. Web Dashboard

Create a web interface for monitoring:

```bash
# Add web framework
pip install flask-dashboard

# Implement monitoring dashboard
```

## 📝 Summary

Congratulations! You've successfully implemented an Evergreen CI/CD Pipeline system. You've learned:

✅ **Dependency Management**: Automated scanning and updating of Docker images  
✅ **GitLab Integration**: API usage, branch creation, and merge requests  
✅ **Scheduling Systems**: Automated execution with APScheduler  
✅ **Configuration Management**: YAML configs with environment overrides  
✅ **API Integration**: Docker Hub registry API patterns  
✅ **Testing Strategies**: Unit, integration, and performance testing  
✅ **CI/CD Integration**: GitLab pipeline automation  
✅ **Monitoring & Observability**: Health checks, logging, and metrics  
✅ **Security Best Practices**: Token management and secure deployments  

### Key Features Implemented

- 🔍 **Dockerfile Scanning**: Automatic detection and parsing
- 🐳 **Docker Hub Integration**: Latest version checking
- 🔄 **GitLab Automation**: Branch creation and MR generation
- ⏰ **Flexible Scheduling**: Cron and interval-based execution
- 🌐 **Webhook API**: Manual triggers and health checks
- 📊 **Comprehensive Logging**: Structured logging with rotation
- 🧪 **Testing Suite**: Unit, integration, and performance tests
- 🚀 **Docker Deployment**: Container-ready with CI/CD integration

This lab demonstrates real-world DevOps automation patterns and provides a solid foundation for implementing dependency management systems in your own projects.

## 📋 Quick Reference Commands

```bash
# Setup
pip install -r requirements.txt
cp config.yaml.example config.yaml

# Testing
python test_scanner.py                    # Basic tests
python test_enhanced_scanner.py          # Enhanced tests
python test_enhanced_scanner.py --integration  # With API tests

# Single Scan
python enhanced_evergreen_scheduler.py --once

# Scheduled Scanning
python enhanced_evergreen_scheduler.py

# Webhook API
curl http://localhost:8080/health         # Health check
curl -X POST http://localhost:8080/trigger  # Manual trigger

# Docker
docker build -t evergreen-scanner .
docker run -p 8080:8080 evergreen-scanner
```

---

**Happy coding! 🚀**

*This lab is part of the GitLab Lab Tutorial series. For more labs and advanced topics, visit the [main repository](https://github.com/ly2xxx/gitlab_lab).*
