#!/usr/bin/env pwsh
# publish.ps1 - Publish markdown files to Confluence using mark CLI
# Usage: .\publish.ps1 <file.md> [options]

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$File = "sample.md",
    
    [Parameter(Mandatory=$false)]
    [string]$Space = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Parent = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Title = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Install = $false
)

# Color output functions
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Warning { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }

Write-Host "=================================================="
Write-Host "📝 Mark - Confluence Publisher"
Write-Host "=================================================="
Write-Host ""

# Install mark if requested
if ($Install) {
    Write-Info "Installing mark CLI..."
    
    if (Test-Path ".\mark.exe") {
        Write-Warning "mark.exe already exists in current directory"
    } else {
        try {
            $url = "https://github.com/kovetskiy/mark/releases/latest/download/mark.exe"
            Write-Info "Downloading from: $url"
            Invoke-WebRequest -Uri $url -OutFile "mark.exe"
            Write-Success "mark.exe downloaded successfully"
        } catch {
            Write-Error "Failed to download mark.exe: $_"
            exit 1
        }
    }
    
    Write-Host ""
}

# Check if mark exists
$markPath = $null
if (Test-Path ".\mark.exe") {
    $markPath = ".\mark.exe"
} elseif (Get-Command mark -ErrorAction SilentlyContinue) {
    $markPath = "mark"
} else {
    Write-Error "mark CLI not found!"
    Write-Info "Run with -Install flag to download: .\publish.ps1 -Install"
    Write-Info "Or download manually from: https://github.com/kovetskiy/mark/releases"
    exit 1
}

Write-Success "Found mark at: $markPath"
Write-Host ""

# Load .env file if exists
$envFile = ".env"
if (Test-Path $envFile) {
    Write-Info "Loading configuration from $envFile..."
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"').Trim("'")
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Success "Configuration loaded"
} else {
    Write-Warning ".env file not found!"
    Write-Info "Copy .env.template to .env and fill in your credentials"
    Write-Host ""
}

# Verify file exists
if (-not (Test-Path $File)) {
    Write-Error "File not found: $File"
    exit 1
}

Write-Success "Found file: $File"
Write-Host ""

# Build mark command
$markArgs = @("--file", $File)

# Add credentials from env or use environment variables
$url = if ($env:CONFLUENCE_URL) { $env:CONFLUENCE_URL } else { "" }
$username = if ($env:CONFLUENCE_USERNAME) { $env:CONFLUENCE_USERNAME } else { "" }
$password = if ($env:CONFLUENCE_PASSWORD) { $env:CONFLUENCE_PASSWORD } else { "" }

if (-not $url -or -not $username -or -not $password) {
    Write-Error "Missing Confluence credentials!"
    Write-Info "Set environment variables or create .env file:"
    Write-Info "  CONFLUENCE_URL"
    Write-Info "  CONFLUENCE_USERNAME"
    Write-Info "  CONFLUENCE_PASSWORD"
    exit 1
}

$markArgs += "--url", $url
$markArgs += "--username", $username
$markArgs += "--password", $password

# Add space
$spaceKey = if ($Space) { $Space } elseif ($env:CONFLUENCE_SPACE) { $env:CONFLUENCE_SPACE } else { "" }
if ($spaceKey) {
    $markArgs += "--space", $spaceKey
    Write-Info "Target space: $spaceKey"
}

# Add parent
$parentPage = if ($Parent) { $Parent } elseif ($env:CONFLUENCE_PARENT) { $env:CONFLUENCE_PARENT } else { "" }
if ($parentPage) {
    $markArgs += "--parent", $parentPage
    Write-Info "Parent page: $parentPage"
}

# Add title
if ($Title) {
    $markArgs += "--title", $Title
    Write-Info "Page title: $Title"
}

# Dry run
if ($DryRun) {
    $markArgs += "--dry-run"
    Write-Warning "DRY RUN MODE - No changes will be made"
}

Write-Host ""
Write-Info "Publishing to Confluence..."
Write-Host ""

# Execute mark
try {
    $output = & $markPath @markArgs 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Published successfully!"
        Write-Host ""
        Write-Host $output
    } else {
        Write-Error "Publishing failed!"
        Write-Host $output
        exit 1
    }
} catch {
    Write-Error "Error executing mark: $_"
    exit 1
}

Write-Host ""
Write-Success "Done!"
