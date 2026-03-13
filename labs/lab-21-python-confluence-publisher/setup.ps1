# Quick setup script for Lab 21

Write-Host "🚀 Lab 21: Python Confluence Publisher - Setup" -ForegroundColor Cyan
Write-Host ""

# Check if .env exists
if (Test-Path ".env") {
    Write-Host "✅ .env file found" -ForegroundColor Green
} else {
    Write-Host "❌ .env file not found!" -ForegroundColor Red
    Write-Host "   Please copy .env.example to .env and configure it" -ForegroundColor Yellow
    exit 1
}

# Check Python
Write-Host "🐍 Checking Python..." -ForegroundColor Cyan
try {
    $pythonVersion = python --version
    Write-Host "✅ $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python not found!" -ForegroundColor Red
    Write-Host "   Please install Python from python.org" -ForegroundColor Yellow
    exit 1
}

# Install dependencies
Write-Host ""
Write-Host "📦 Installing dependencies..." -ForegroundColor Cyan
pip install -r requirements.txt

Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Edit .env with your Confluence credentials"
Write-Host "2. Run: python publish.py example.md"
Write-Host ""
Write-Host "For help: python publish.py" -ForegroundColor Yellow
