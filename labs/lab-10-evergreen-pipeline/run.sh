#!/bin/bash
# Run script for Evergreen Scanner Lab
# This script sets up the environment and runs the evergreen scanner

set -e

echo "🚀 Evergreen Scanner Lab - Setup and Run"
echo "======================================"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or later."
    exit 1
fi

echo "✅ Python 3 found: $(python3 --version)"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📚 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Check if configuration exists
if [ ! -f ".env" ]; then
    echo "⚠️  Configuration file not found!"
    echo "📝 Please copy config.env.example to .env and configure your GitLab settings:"
    echo "   cp config.env.example .env"
    echo "   # Then edit .env with your GitLab URL, access token, and project path"
    exit 1
fi

# Load environment variables
echo "🔧 Loading configuration..."
export $(cat .env | grep -v '^#' | xargs)

# Validate required environment variables
if [ -z "$GITLAB_ACCESS_TOKEN" ] || [ -z "$GITLAB_PROJECT_PATH" ]; then
    echo "❌ Missing required configuration:"
    echo "   GITLAB_ACCESS_TOKEN and GITLAB_PROJECT_PATH must be set in .env"
    exit 1
fi

echo "✅ Configuration loaded"
echo "   GitLab URL: ${GITLAB_URL:-https://gitlab.com}"
echo "   Project: $GITLAB_PROJECT_PATH"

# Run tests first
echo "🧪 Running tests..."
python test_scanner.py

if [ $? -eq 0 ]; then
    echo "✅ Tests passed!"
    echo "🔍 Running Evergreen Scanner..."
    python evergreen_scanner.py
else
    echo "❌ Tests failed. Please check the implementation."
    exit 1
fi

echo "🎉 Evergreen Scanner completed!"
echo "Check your GitLab project for any new merge requests with dependency updates."
