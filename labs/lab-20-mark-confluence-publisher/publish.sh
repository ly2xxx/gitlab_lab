#!/bin/bash
# publish.sh - Publish markdown files to Confluence using mark CLI
# Usage: ./publish.sh <file.md> [options]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "=================================================="
echo "📝 Mark - Confluence Publisher"
echo "=================================================="
echo ""

# Parse arguments
FILE="${1:-sample.md}"
SPACE=""
PARENT=""
TITLE=""
DRY_RUN=false
INSTALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --space)
      SPACE="$2"
      shift 2
      ;;
    --parent)
      PARENT="$2"
      shift 2
      ;;
    --title)
      TITLE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --install)
      INSTALL=true
      shift
      ;;
    *)
      FILE="$1"
      shift
      ;;
  esac
done

# Install mark if requested
if [ "$INSTALL" = true ]; then
  info "Installing mark CLI..."
  
  if [ -f "./mark" ]; then
    warning "mark already exists in current directory"
  else
    OS=$(uname -s)
    ARCH=$(uname -m)
    
    case "$OS" in
      Linux)
        if [ "$ARCH" = "x86_64" ]; then
          BINARY="mark-linux-amd64"
        elif [ "$ARCH" = "aarch64" ]; then
          BINARY="mark-linux-arm64"
        else
          error "Unsupported architecture: $ARCH"
          exit 1
        fi
        ;;
      Darwin)
        if [ "$ARCH" = "x86_64" ]; then
          BINARY="mark-darwin-amd64"
        elif [ "$ARCH" = "arm64" ]; then
          BINARY="mark-darwin-arm64"
        else
          error "Unsupported architecture: $ARCH"
          exit 1
        fi
        ;;
      *)
        error "Unsupported OS: $OS"
        exit 1
        ;;
    esac
    
    URL="https://github.com/kovetskiy/mark/releases/latest/download/$BINARY"
    info "Downloading from: $URL"
    
    if curl -LO "$URL"; then
      mv "$BINARY" mark
      chmod +x mark
      success "mark downloaded successfully"
    else
      error "Failed to download mark"
      exit 1
    fi
  fi
  
  echo ""
fi

# Check if mark exists
MARK_PATH=""
if [ -f "./mark" ]; then
  MARK_PATH="./mark"
elif command -v mark &> /dev/null; then
  MARK_PATH="mark"
else
  error "mark CLI not found!"
  info "Run with --install flag to download: ./publish.sh --install"
  info "Or download manually from: https://github.com/kovetskiy/mark/releases"
  exit 1
fi

success "Found mark at: $MARK_PATH"
echo ""

# Load .env file if exists
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  info "Loading configuration from $ENV_FILE..."
  set -a
  source "$ENV_FILE"
  set +a
  success "Configuration loaded"
else
  warning ".env file not found!"
  info "Copy .env.template to .env and fill in your credentials"
  echo ""
fi

# Verify file exists
if [ ! -f "$FILE" ]; then
  error "File not found: $FILE"
  exit 1
fi

success "Found file: $FILE"
echo ""

# Build mark command
MARK_ARGS=("--file" "$FILE")

# Add credentials
if [ -z "$CONFLUENCE_URL" ] || [ -z "$CONFLUENCE_USERNAME" ] || [ -z "$CONFLUENCE_PASSWORD" ]; then
  error "Missing Confluence credentials!"
  info "Set environment variables or create .env file:"
  info "  CONFLUENCE_URL"
  info "  CONFLUENCE_USERNAME"
  info "  CONFLUENCE_PASSWORD"
  exit 1
fi

MARK_ARGS+=("--url" "$CONFLUENCE_URL")
MARK_ARGS+=("--username" "$CONFLUENCE_USERNAME")
MARK_ARGS+=("--password" "$CONFLUENCE_PASSWORD")

# Add space
if [ -n "$SPACE" ]; then
  MARK_ARGS+=("--space" "$SPACE")
  info "Target space: $SPACE"
elif [ -n "$CONFLUENCE_SPACE" ]; then
  MARK_ARGS+=("--space" "$CONFLUENCE_SPACE")
  info "Target space: $CONFLUENCE_SPACE"
fi

# Add parent
if [ -n "$PARENT" ]; then
  MARK_ARGS+=("--parent" "$PARENT")
  info "Parent page: $PARENT"
elif [ -n "$CONFLUENCE_PARENT" ]; then
  MARK_ARGS+=("--parent" "$CONFLUENCE_PARENT")
  info "Parent page: $CONFLUENCE_PARENT"
fi

# Add title
if [ -n "$TITLE" ]; then
  MARK_ARGS+=("--title" "$TITLE")
  info "Page title: $TITLE"
fi

# Dry run
if [ "$DRY_RUN" = true ]; then
  MARK_ARGS+=("--dry-run")
  warning "DRY RUN MODE - No changes will be made"
fi

echo ""
info "Publishing to Confluence..."
echo ""

# Execute mark
if "$MARK_PATH" "${MARK_ARGS[@]}"; then
  echo ""
  success "Published successfully!"
else
  echo ""
  error "Publishing failed!"
  exit 1
fi

echo ""
success "Done!"
