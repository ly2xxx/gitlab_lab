# 🚀 **Lab 0: GitLab Self-Hosting with Docker** (60 minutes)

## 🎯 Learning Objectives

By the end of this lab, you'll have:
- **Self-hosted GitLab CE instance** running locally with Docker
- **GitLab Runner configured** for executing CI/CD pipelines
- **Complete GitLab environment** ready for hands-on learning
- **Understanding of GitLab architecture** and core components
- **Production-ready configuration** that can scale to team use

## 🔑 Why This Lab Matters

This foundational lab is **essential** because it:
- **Eliminates dependency** on GitLab.com for learning
- **Provides full control** over your GitLab environment
- **Enables offline learning** and experimentation
- **Mirrors enterprise setups** used in production
- **Allows unlimited private repositories** and CI/CD minutes
- **Supports team learning** environments

## 📋 Prerequisites

### System Requirements
- **Minimum**: 4GB RAM, 10GB disk space
- **Recommended**: 8GB RAM, 20GB disk space
- **Docker Desktop** installed and running
- **Docker Compose** v2.0 or higher
- **Git** client installed

### Platform Support
- ✅ **Windows 11** with Docker Desktop (Recommended)
- ✅ **Windows 11** with WSL2 and Docker Desktop
- ✅ **macOS** with Docker Desktop
- ✅ **Linux** with Docker Engine and Docker Compose

### Pre-installation Checks

**For Windows 11 (PowerShell or Command Prompt):**
```powershell
# Verify Docker installation
docker --version          # Should be 24.0+ 
docker-compose --version   # Should be v2.0+

# Check available resources
docker system df          # Check disk space
docker system info | findstr "Total Memory"  # Check memory
```

**For WSL2/Linux:**
```bash
# Verify Docker installation
docker --version          # Should be 24.0+ 
docker-compose --version   # Should be v2.0+

# Check available resources
docker system df          # Check disk space
docker system info | grep -i memory  # Check memory
```

## 🏗️ Part 1: GitLab CE Installation (25 minutes)

### Step 1: Environment Preparation

1. **Navigate to lab directory:**
   
   **Windows (PowerShell/Command Prompt):**
   ```powershell
   cd labs\lab-00-gitlab-self-host-docker
   ```
   
   **WSL2/Linux:**
   ```bash
   cd labs/lab-00-gitlab-self-host-docker
   ```

2. **Create data directories:**
   
   **Windows (PowerShell):**
   ```powershell
   # Create directories in your user profile (recommended for Docker Desktop)
   mkdir -p $env:USERPROFILE\gitlab-data\{config,logs,data}
   
   # Or create in project directory (alternative)
   mkdir -p .\gitlab-data\{config,logs,data}
   ```
   
   **WSL2/Linux:**
   ```bash
   sudo mkdir -p /srv/gitlab/{config,logs,data}
   sudo chown -R $USER:$USER /srv/gitlab
   ```

3. **Set environment variables:**
   
   **Windows (PowerShell):**
   ```powershell
   # Set for current session
   $env:GITLAB_HOME = "$env:USERPROFILE\gitlab-data"
   $env:GITLAB_HOSTNAME = "localhost"
   
   # Or use project directory
   $env:GITLAB_HOME = ".\gitlab-data"
   ```
   
   **WSL2/Linux:**
   ```bash
   export GITLAB_HOME=/srv/gitlab
   export GITLAB_HOSTNAME=localhost
   ```

### Step 2: GitLab CE Deployment

1. **Start GitLab with Docker Compose:**
   
   **Windows/WSL2/Linux:**
   ```bash
   docker-compose up -d
   ```

2. **Monitor startup process:**
   
   **Windows (PowerShell):**
   ```powershell
   # Watch GitLab startup (takes 3-5 minutes)
   docker-compose logs -f gitlab
   
   # Check when GitLab is ready
   docker-compose exec gitlab gitlab-ctl status
   ```
   
   **WSL2/Linux:**
   ```bash
   # Watch GitLab startup (takes 3-5 minutes)
   docker-compose logs -f gitlab
   
   # Check when GitLab is ready
   docker-compose exec gitlab gitlab-ctl status
   ```

3. **Verify installation:**
   
   **Windows (PowerShell):**
   ```powershell
   # Check all services are running
   docker-compose ps
   
   # Test GitLab accessibility (Windows)
   Invoke-WebRequest -Uri https://localhost -SkipCertificateCheck
   
   # Or use curl if available
   curl -k https://localhost
   ```
   
   **WSL2/Linux:**
   ```bash
   # Check all services are running
   docker-compose ps
   
   # Test GitLab accessibility
   curl -k https://localhost
   ```

### Step 3: Initial Configuration

1. **Access GitLab interface:**
   - Open browser to: `https://localhost`
   - Accept the self-signed certificate warning

2. **Get initial root password:**
   
   **Windows/WSL2/Linux:**
   ```bash
   # Get auto-generated root password
   docker-compose exec gitlab cat /etc/gitlab/initial_root_password
   ```

3. **First login:**
   - Username: `root`
   - Password: Use the password from step 2
   - **Immediately change the password** for security

## 🏃 Part 2: GitLab Runner Setup (20 minutes)

### Step 1: Runner Registration

1. **Get registration token:**
   - In GitLab: Go to **Admin Area** → **Runners**
   - Copy the **registration token**

2. **Register the runner:**
   
   **Windows/WSL2/Linux:**
   ```bash
   # Register runner interactively
   docker-compose exec runner gitlab-runner register
   
   # When prompted, use:
   # GitLab instance URL: https://gitlab/
   # Registration token: [paste token from GitLab]
   # Description: Local Docker Runner
   # Tags: docker,local
   # Executor: docker
   # Default Docker image: alpine:latest
   ```

3. **Verify runner registration:**
   
   **Windows/WSL2/Linux:**
   ```bash
   # Check runner status
   docker-compose exec runner gitlab-runner list
   
   # In GitLab UI: Admin Area → Runners (should show green runner)
   ```

### Step 2: Runner Configuration

1. **Configure runner for optimal performance:**
   
   **Windows/WSL2/Linux:**
   ```bash
   # Edit runner configuration (use vi, nano, or your preferred editor)
   docker-compose exec runner vi /etc/gitlab-runner/config.toml
   
   # Alternative: use nano if vi is not familiar
   docker-compose exec runner nano /etc/gitlab-runner/config.toml
   ```

2. **Test runner with a simple pipeline:**
   - Create a test project in GitLab
   - Add a basic `.gitlab-ci.yml` file
   - Commit and verify the pipeline runs

## 🔧 Part 3: Essential Configuration (15 minutes)

### Step 1: GitLab Settings

1. **Disable sign-ups (recommended for local use):**
   - Go to **Admin Area** → **Settings** → **General**
   - Expand **Sign-up restrictions**
   - Uncheck **Sign-up enabled**

2. **Configure CI/CD settings:**
   - Go to **Admin Area** → **Settings** → **CI/CD**
   - Set **Default CI/CD configuration file**: `.gitlab-ci.yml`
   - Enable **Shared runners** if needed

3. **Set up Container Registry:**
   - Go to **Admin Area** → **Settings** → **Packages and registries**
   - Enable **Container Registry**

### Step 2: Create Your First Project

1. **Create a new project:**
   - Click **New project** → **Create blank project**
   - Project name: `gitlab-lab-test`
   - Visibility: **Private**
   - Initialize with README: ✅

2. **Clone the project locally:**
   
   **Windows (PowerShell/Command Prompt):**
   ```powershell
   git clone https://localhost/root/gitlab-lab-test.git
   cd gitlab-lab-test
   ```
   
   **WSL2/Linux:**
   ```bash
   git clone https://localhost/root/gitlab-lab-test.git
   cd gitlab-lab-test
   ```

3. **Add a test pipeline:**
   
   **Windows (PowerShell):**
   ```powershell
   # Create a basic .gitlab-ci.yml
   @"
   test_job:
     script:
       - echo "Hello from self-hosted GitLab!"
       - echo "Runner: `$CI_RUNNER_DESCRIPTION"
       - echo "Project: `$CI_PROJECT_NAME"
   "@ | Out-File -FilePath .gitlab-ci.yml -Encoding UTF8
   
   # Commit and push
   git add .gitlab-ci.yml
   git commit -m "Add test pipeline"
   git push origin main
   ```
   
   **WSL2/Linux:**
   ```bash
   # Create a basic .gitlab-ci.yml
   cat > .gitlab-ci.yml << 'EOF'
   test_job:
     script:
       - echo "Hello from self-hosted GitLab!"
       - echo "Runner: $CI_RUNNER_DESCRIPTION"
       - echo "Project: $CI_PROJECT_NAME"
   EOF
   
   # Commit and push
   git add .gitlab-ci.yml
   git commit -m "Add test pipeline"
   git push origin main
   ```

4. **Verify pipeline execution:**
   - Go to project → **CI/CD** → **Pipelines**
   - Confirm the pipeline runs successfully

## ✅ Validation Checklist

### GitLab Instance Health
- [ ] GitLab web interface accessible at `https://localhost`
- [ ] All GitLab services running (check with `gitlab-ctl status`)
- [ ] Root user can log in successfully
- [ ] Container Registry is accessible

### Runner Configuration
- [ ] GitLab Runner registered and visible in Admin Area
- [ ] Runner shows as "online" (green status)
- [ ] Test pipeline executes successfully
- [ ] Runner can pull Docker images

### Basic Functionality
- [ ] Can create new projects
- [ ] Can clone repositories via HTTPS
- [ ] CI/CD pipelines execute without errors
- [ ] Web interface is responsive and functional

### Performance Verification
```bash
# Check resource usage
docker stats --no-stream

# Verify GitLab responsiveness
curl -w "Response time: %{time_total}s\n" -o /dev/null -s https://localhost

# Check runner logs
docker-compose logs runner | tail -20
```

## 🔍 Troubleshooting Guide

### Common Issues and Solutions

**GitLab takes too long to start:**

*Windows/PowerShell:*
```powershell
# Increase Docker memory to 8GB minimum for Windows
# Docker Desktop → Settings → Resources → Memory: 8GB+
# Check startup progress:
docker-compose logs gitlab | Select-String "gitlab Reconfigured"
```

*WSL2/Linux:*
```bash
# Check startup progress:
docker-compose logs gitlab | grep "gitlab Reconfigured"
```

**Runner registration fails:**

*All platforms:*
```bash
# Check GitLab connectivity from runner:
docker-compose exec runner curl -k https://gitlab/
# Verify registration token is correct
```

**502 Bad Gateway error:**

*All platforms:*
```bash
# Wait longer for GitLab to fully start (Windows may take 10+ minutes)
# Check if all services are running:
docker-compose exec gitlab gitlab-ctl status
```

**SSL certificate warnings:**
- This is normal for self-hosted setups
- Add certificate exception in browser
- For production, configure proper SSL certificates

**Windows-Specific Issues:**

**Docker Desktop not starting:**
- Restart Docker Desktop as Administrator
- Check Windows features: Hyper-V, Windows Subsystem for Linux
- Ensure virtualization is enabled in BIOS

**Path mounting issues:**
```powershell
# Use full Windows paths if relative paths fail:
$env:GITLAB_HOME = "C:\GitLab\data"
# Or use the current directory:
$env:GITLAB_HOME = "$PWD\gitlab-data"
```

**PowerShell execution policy:**
```powershell
# If PowerShell script fails to run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# Then run the setup script:
.\scripts\setup-gitlab-windows.ps1
```

**Firewall blocking access:**
- Windows Defender may block Docker ports
- Add Docker Desktop to firewall exceptions
- Or temporarily disable Windows Defender Firewall for testing

**Performance issues on Windows:**
```powershell
# Increase Docker resources (minimum for Windows):
# Docker Desktop → Settings → Resources
# CPU: 4+ cores, Memory: 8GB+, Disk: 40GB+
# Enable WSL2 integration if available
```

**Volume mounting permissions:**
- Docker Desktop automatically handles Windows path mounting
- If issues persist, try running Docker Desktop as Administrator
- Use named volumes instead of bind mounts if problems continue

### Platform-Specific Commands

**Windows PowerShell:**
```powershell
# Use PowerShell setup script:
.\scripts\setup-gitlab-windows.ps1

# Or use batch file for Command Prompt:
.\scripts\setup-gitlab-windows.bat

# Manual Docker Compose with Windows paths:
$env:GITLAB_HOME = "$PWD\gitlab-data"
docker-compose up -d
```

**WSL2 (Windows Subsystem for Linux):**
```bash
# Use Linux commands within WSL2:
cd /mnt/c/path/to/gitlab_lab/labs/lab-00-gitlab-self-host-docker
export GITLAB_HOME=/srv/gitlab
sudo mkdir -p $GITLAB_HOME/{config,logs,data}
docker-compose up -d
```

## 🚀 Next Steps

### Immediate Actions
1. **Bookmark your GitLab instance**: `https://localhost`
2. **Save your root credentials** securely
3. **Create additional user accounts** for team members
4. **Configure backup strategy** for important data

### Advanced Configuration (Optional)
1. **Custom domain setup** with proper SSL certificates
2. **LDAP/SAML integration** for enterprise authentication
3. **Email configuration** for notifications
4. **External database** setup for better performance

### Ready for Lab 1!
Your GitLab environment is now ready for the tutorial labs:
- **Lab 1**: Basic Pipeline Setup → Use your local GitLab
- **Lab 2**: Stages and Jobs → Test with your runner
- **Continue through all labs** with your own GitLab instance

## 📊 What You've Accomplished

🎉 **Congratulations!** You now have:

- ✅ **Production-ready GitLab CE** instance running locally
- ✅ **Fully configured GitLab Runner** for CI/CD execution
- ✅ **Complete DevOps environment** for hands-on learning
- ✅ **Foundation for all subsequent labs** in this tutorial
- ✅ **Skills to deploy GitLab** in any environment

## 🔗 Useful Commands Reference

### Windows PowerShell
```powershell
# GitLab Management
docker-compose up -d              # Start GitLab
docker-compose down               # Stop GitLab
docker-compose logs -f gitlab     # View GitLab logs
docker-compose restart gitlab     # Restart GitLab

# Runner Management
docker-compose exec runner gitlab-runner list          # List runners
docker-compose exec runner gitlab-runner verify        # Verify runners
docker-compose exec runner gitlab-runner restart       # Restart runner

# Backup & Maintenance
docker-compose exec gitlab gitlab-backup create        # Create backup
docker-compose exec gitlab gitlab-ctl reconfigure      # Reconfigure GitLab
docker-compose exec gitlab gitlab-ctl status           # Check service status

# System Maintenance
docker system prune -f           # Clean unused Docker resources
docker-compose pull              # Update to latest images

# Windows-specific commands
Get-Process *docker*              # Check Docker processes
Restart-Service *docker*          # Restart Docker service (if needed)
```

### WSL2/Linux
```bash
# GitLab Management
docker-compose up -d              # Start GitLab
docker-compose down               # Stop GitLab
docker-compose logs -f gitlab     # View GitLab logs
docker-compose restart gitlab     # Restart GitLab

# Runner Management
docker-compose exec runner gitlab-runner list          # List runners
docker-compose exec runner gitlab-runner verify        # Verify runners
docker-compose exec runner gitlab-runner restart       # Restart runner

# Backup & Maintenance
docker-compose exec gitlab gitlab-backup create        # Create backup
docker-compose exec gitlab gitlab-ctl reconfigure      # Reconfigure GitLab
docker-compose exec gitlab gitlab-ctl status           # Check service status

# System Maintenance
docker system prune -f           # Clean unused Docker resources
docker-compose pull              # Update to latest images
```

## 📚 Additional Resources

- [GitLab Installation Documentation](https://docs.gitlab.com/ee/install/docker.html)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [GitLab Administration Guide](https://docs.gitlab.com/ee/administration/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

---

**Ready to start your GitLab CI/CD journey?** 🎆

Your self-hosted GitLab instance is now ready for [Lab 1: Basic Pipeline Setup](../lab-01-basic-pipeline/)!