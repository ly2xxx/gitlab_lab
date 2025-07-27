# setup-gitlab-windows.ps1 - PowerShell script for Windows 11 GitLab CE setup

param(
    [string]$DataPath = ".\gitlab-data",
    [switch]$UseUserProfile,
    [switch]$Help
)

# Colors for output
$Colors = @{
    Red    = "Red"
    Green  = "Green"
    Yellow = "Yellow"
    Blue   = "Blue"
    White  = "White"
}

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red
}

function Show-Help {
    Write-Host @"
GitLab CE Windows Setup Script

SYNOPSIS
    Sets up GitLab CE on Windows 11 with Docker Desktop

SYNTAX
    .\setup-gitlab-windows.ps1 [-DataPath <string>] [-UseUserProfile] [-Help]

PARAMETERS
    -DataPath <string>
        Path where GitLab data will be stored (default: .\gitlab-data)
        
    -UseUserProfile
        Store GitLab data in user profile directory
        
    -Help
        Show this help message

EXAMPLES
    .\setup-gitlab-windows.ps1
        # Use default data path (.\gitlab-data)
        
    .\setup-gitlab-windows.ps1 -DataPath "C:\GitLab"
        # Use custom data path
        
    .\setup-gitlab-windows.ps1 -UseUserProfile
        # Store data in user profile

"@ -ForegroundColor $Colors.White
}

# Check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check if Docker is installed
    try {
        $dockerVersion = docker --version
        Write-Status "Docker found: $dockerVersion"
    }
    catch {
        Write-Error "Docker is not installed or not in PATH. Please install Docker Desktop first."
        exit 1
    }
    
    # Check if Docker Compose is available
    try {
        $composeVersion = docker-compose --version
        Write-Status "Docker Compose found: $composeVersion"
    }
    catch {
        Write-Error "Docker Compose is not available. Please ensure Docker Desktop is properly installed."
        exit 1
    }
    
    # Check if Docker is running
    try {
        docker info | Out-Null
        Write-Status "Docker daemon is running"
    }
    catch {
        Write-Error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    }
    
    # Check system resources
    try {
        $memoryInfo = docker system info | Select-String "Total Memory"
        Write-Status "Available Docker memory: $memoryInfo"
    }
    catch {
        Write-Warning "Could not retrieve memory information"
    }
    
    Write-Success "Prerequisites check passed!"
}

# Setup environment
function Initialize-Environment {
    Write-Status "Setting up environment..."
    
    # Determine data path
    if ($UseUserProfile) {
        $script:GitLabHome = Join-Path $env:USERPROFILE "gitlab-data"
    } else {
        $script:GitLabHome = $DataPath
    }
    
    Write-Status "GitLab data will be stored in: $script:GitLabHome"
    
    # Create data directories
    $directories = @("config", "logs", "data")
    foreach ($dir in $directories) {
        $fullPath = Join-Path $script:GitLabHome $dir
        if (!(Test-Path $fullPath)) {
            New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
            Write-Status "Created directory: $fullPath"
        }
    }
    
    # Create SSL directory
    $sslPath = ".\config\ssl"
    if (!(Test-Path $sslPath)) {
        New-Item -ItemType Directory -Force -Path $sslPath | Out-Null
    }
    
    # Generate self-signed certificate
    $certPath = Join-Path $sslPath "gitlab.crt"
    $keyPath = Join-Path $sslPath "gitlab.key"
    
    if (!(Test-Path $certPath)) {
        Write-Status "Generating self-signed SSL certificate..."
        
        # Check if OpenSSL is available
        try {
            openssl version | Out-Null
            
            # Generate certificate using OpenSSL
            $subject = "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=localhost"
            openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj $subject -keyout $keyPath -out $certPath
            
            Write-Success "SSL certificate generated using OpenSSL"
        }
        catch {
            Write-Warning "OpenSSL not found. Generating certificate using PowerShell..."
            
            # Generate certificate using PowerShell (requires elevated permissions)
            try {
                $cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "cert:\LocalMachine\My" -KeyUsage DigitalSignature,KeyEncipherment -KeyAlgorithm RSA -KeyLength 2048
                
                # Export certificate
                Export-Certificate -Cert $cert -FilePath $certPath -Type CERT | Out-Null
                Export-PfxCertificate -Cert $cert -FilePath ($certPath -replace ".crt", ".pfx") -Password (ConvertTo-SecureString -String "gitlab" -Force -AsPlainText) | Out-Null
                
                Write-Success "SSL certificate generated using PowerShell"
            }
            catch {
                Write-Warning "Could not generate SSL certificate. GitLab will use default certificates."
            }
        }
    }
    
    # Set environment variables for Docker Compose
    $env:GITLAB_HOME = $script:GitLabHome
    $env:GITLAB_HOSTNAME = "localhost"
    
    Write-Success "Environment setup completed!"
}

# Start GitLab
function Start-GitLab {
    Write-Status "Starting GitLab CE..."
    
    # Check if docker-compose.yml exists
    if (!(Test-Path "docker-compose.yml")) {
        Write-Error "docker-compose.yml not found. Please run this script from the lab directory."
        exit 1
    }
    
    # Pull latest images
    Write-Status "Pulling latest Docker images..."
    docker-compose pull
    
    # Create gitlab-data directory structure if using current directory
    if ($DataPath -eq ".\gitlab-data") {
        $directories = @("config", "logs", "data")
        foreach ($dir in $directories) {
            $fullPath = Join-Path "gitlab-data" $dir
            if (!(Test-Path $fullPath)) {
                New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
            }
        }
    }
    
    # Start services
    Write-Status "Starting GitLab services..."
    docker-compose up -d
    
    Write-Status "GitLab is starting up... This may take 5-10 minutes on Windows."
    Write-Warning "GitLab will be available at: https://localhost"
    
    # Wait for GitLab to be ready
    Write-Status "Waiting for GitLab to be ready..."
    $timeout = 600  # 10 minutes for Windows
    $count = 0
    
    do {
        Start-Sleep -Seconds 15
        $count += 15
        
        try {
            $response = Invoke-WebRequest -Uri "https://localhost" -SkipCertificateCheck -TimeoutSec 10 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Success "GitLab is ready!"
                break
            }
        }
        catch {
            Write-Host "." -NoNewline
        }
        
        if ($count % 60 -eq 0) {
            Write-Host ""
            Write-Status "Still waiting... ($count/$timeout seconds)"
        }
        
    } while ($count -lt $timeout)
    
    if ($count -ge $timeout) {
        Write-Error "GitLab startup timed out. Check logs with: docker-compose logs gitlab"
        exit 1
    }
}

# Display setup information
function Show-SetupInfo {
    Write-Success "GitLab CE installation completed!"
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor $Colors.Green
    Write-Host "🚀 GitLab is now running!" -ForegroundColor $Colors.Green
    Write-Host "===================================================================" -ForegroundColor $Colors.Green
    Write-Host ""
    Write-Host "📍 Access URLs:" -ForegroundColor $Colors.Blue
    Write-Host "   Web Interface: https://localhost"
    Write-Host "   Container Registry: https://localhost:5050"
    Write-Host "   SSH Git Access: ssh://git@localhost:2224"
    Write-Host ""
    Write-Host "🔐 Initial Login:" -ForegroundColor $Colors.Blue
    Write-Host "   Username: root"
    Write-Host "   Password: Run this command to get the password:" -ForegroundColor $Colors.Yellow
    Write-Host "   docker-compose exec gitlab cat /etc/gitlab/initial_root_password"
    Write-Host ""
    Write-Host "🏃 GitLab Runner:" -ForegroundColor $Colors.Blue
    Write-Host "   Runner will start automatically after GitLab is ready"
    Write-Host "   Register it using the token from: Admin Area → Runners"
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor $Colors.Blue
    Write-Host "   1. Open https://localhost in your browser"
    Write-Host "   2. Accept the SSL certificate warning"
    Write-Host "   3. Login with root and the initial password"
    Write-Host "   4. Change the root password immediately"
    Write-Host "   5. Register the GitLab Runner"
    Write-Host "   6. Create your first project"
    Write-Host ""
    Write-Host "🛠️ Useful Commands:" -ForegroundColor $Colors.Blue
    Write-Host "   View logs:     docker-compose logs -f gitlab"
    Write-Host "   Stop GitLab:   docker-compose down"
    Write-Host "   Restart:       docker-compose restart"
    Write-Host "   Status:        docker-compose ps"
    Write-Host ""
    Write-Host "📁 Data Location:" -ForegroundColor $Colors.Blue
    Write-Host "   GitLab data is stored in: $script:GitLabHome"
    Write-Host ""
    Write-Host "Happy coding with GitLab! 🎉" -ForegroundColor $Colors.Green
}

# Get initial root password
function Get-RootPassword {
    Write-Status "Retrieving initial root password..."
    Write-Host ""
    Write-Host "===================================================================" -ForegroundColor $Colors.Yellow
    Write-Host "Initial Root Password:" -ForegroundColor $Colors.Yellow
    
    try {
        $password = docker-compose exec gitlab cat /etc/gitlab/initial_root_password | Select-String "Password:"
        Write-Host $password -ForegroundColor $Colors.White
    }
    catch {
        Write-Warning "Could not retrieve password automatically."
        Write-Status "Try running: docker-compose exec gitlab cat /etc/gitlab/initial_root_password"
    }
    
    Write-Host "===================================================================" -ForegroundColor $Colors.Yellow
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Host "===================================================================" -ForegroundColor $Colors.Green
    Write-Host "🐳 GitLab CE Self-Hosting Setup for Windows 11" -ForegroundColor $Colors.Green
    Write-Host "===================================================================" -ForegroundColor $Colors.Green
    Write-Host ""
    
    Test-Prerequisites
    Initialize-Environment
    Start-GitLab
    Show-SetupInfo
    
    # Wait a bit then try to get password
    Start-Sleep -Seconds 30
    Get-RootPassword
}

# Handle script interruption
trap {
    Write-Warning "Script interrupted. Cleaning up..."
    try {
        docker-compose down 2>$null
    }
    catch {}
    exit 1
}

# Run main function
Main