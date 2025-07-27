# GitLab Self-Hosting on Windows 11 - Quick Guide

This guide provides Windows-specific instructions for Lab 0.

## 🎯 Windows 11 Quick Setup

### Option 1: PowerShell (Recommended)
```powershell
# Navigate to lab directory
cd labs\lab-00-gitlab-self-host-docker

# Run automated setup script
.\scripts\setup-gitlab-windows.ps1

# Or with custom data path
.\scripts\setup-gitlab-windows.ps1 -DataPath "C:\GitLab"
```

### Option 2: Command Prompt
```cmd
cd labs\lab-00-gitlab-self-host-docker
scripts\setup-gitlab-windows.bat
```

### Option 3: Manual Setup
```powershell
# Create data directories
mkdir gitlab-data\config, gitlab-data\logs, gitlab-data\data

# Set environment variable
$env:GITLAB_HOME = "$PWD\gitlab-data"

# Start GitLab
docker-compose up -d
```

## 🔧 Windows-Specific Requirements

### Docker Desktop Settings
- **Memory**: 8GB minimum (recommended 12GB+)
- **CPU**: 4+ cores
- **Disk**: 40GB+ available space
- **Enable WSL2** integration if available

### Firewall Configuration
```powershell
# If Windows Firewall blocks access, add exceptions:
New-NetFirewallRule -DisplayName "GitLab HTTP" -Direction Inbound -Port 80 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "GitLab HTTPS" -Direction Inbound -Port 443 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "GitLab SSH" -Direction Inbound -Port 2224 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "GitLab Registry" -Direction Inbound -Port 5050 -Protocol TCP -Action Allow
```

## 📁 Data Storage Options

### Option 1: Project Directory (Default)
```
labs\lab-00-gitlab-self-host-docker\gitlab-data\
├── config\
├── logs\
└── data\
```

### Option 2: User Profile
```
C:\Users\{YourName}\gitlab-data\
├── config\
├── logs\
└── data\
```

### Option 3: Custom Location
```powershell
$env:GITLAB_HOME = "C:\GitLab\data"
```

## 🚨 Common Windows Issues

### PowerShell Execution Policy
```powershell
# If scripts can't run:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Docker Desktop Not Starting
1. Restart as Administrator
2. Check Windows Features:
   - Hyper-V
   - Windows Subsystem for Linux
   - Virtual Machine Platform
3. Enable virtualization in BIOS/UEFI

### Volume Mount Issues
```powershell
# If path mounting fails, try full paths:
$env:GITLAB_HOME = "C:\Users\$env:USERNAME\gitlab-data"

# Or use forward slashes:
$env:GITLAB_HOME = "$PWD/gitlab-data"
```

### Performance Issues
```powershell
# Check Docker resource usage:
docker system df
docker system info

# Restart Docker Desktop:
Get-Process *docker* | Stop-Process -Force
# Then restart Docker Desktop application
```

## 📋 Windows Validation Checklist

- [ ] Docker Desktop installed and running
- [ ] Windows Firewall configured or disabled for testing
- [ ] Sufficient resources allocated (8GB+ RAM)
- [ ] GitLab accessible at `https://localhost`
- [ ] Initial password retrieved successfully
- [ ] GitLab Runner registered and online

## 🔗 Windows-Specific Commands

### Check GitLab Status
```powershell
# View containers
docker-compose ps

# Check GitLab health
Invoke-WebRequest -Uri https://localhost -SkipCertificateCheck

# Get initial password
docker-compose exec gitlab cat /etc/gitlab/initial_root_password
```

### Troubleshooting
```powershell
# View logs
docker-compose logs -f gitlab

# Restart services
docker-compose restart

# Check Windows processes
Get-Process *docker*
Get-Process *gitlab*
```

### Cleanup
```powershell
# Stop and remove
docker-compose down -v

# Remove data (careful!)
Remove-Item -Recurse -Force gitlab-data
```

## 🎉 Success Indicators

When setup is complete, you should see:
- GitLab web interface at `https://localhost`
- No Docker errors in logs
- GitLab Runner showing as "online"
- Able to create and run test pipeline

**Total setup time on Windows**: 10-15 minutes (depending on internet speed and system performance)

---

**Need help?** Check the main README.md troubleshooting section or Windows-specific issues above.