#!/bin/bash
# Enhanced script to update Docker base images using version mappings
# Now configurable via environment variables for component reusability

set -e

# Configuration variables
DOCKERFILE_PATH="${DOCKERFILE_PATH:-sample-app/Dockerfile}"
VERSION_MAPPINGS="${VERSION_MAPPINGS:-}"
BACKUP_FILES="${CREATE_BACKUP:-true}"
SHOW_DIFF="${SHOW_DIFF:-true}"

# Default version mappings if none provided
DEFAULT_MAPPINGS="python:3.9->3.11
python:3.10->3.11
node:16->18
node:17->18
alpine:3.15->3.18
alpine:3.16->3.18
alpine:3.17->3.18
ubuntu:20.04->22.04
ubuntu:21.04->22.04
nginx:1.20->1.24
nginx:1.21->1.24"

# Use provided mappings or defaults
MAPPINGS="${VERSION_MAPPINGS:-$DEFAULT_MAPPINGS}"

echo "Enhanced Docker Base Image Updater"
echo "===================================="

if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE_PATH"
    echo "Available files in directory:"
    ls -la "$(dirname "$DOCKERFILE_PATH")" 2>/dev/null || echo "Directory not found"
    exit 1
fi

echo "Updating Docker base images in $DOCKERFILE_PATH"
echo "Using $(echo "$MAPPINGS" | wc -l) version mappings"

# Backup original file if requested
if [ "$BACKUP_FILES" = "true" ]; then
    BACKUP_PATH="${DOCKERFILE_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$DOCKERFILE_PATH" "$BACKUP_PATH"
    echo "Backup created: $BACKUP_PATH"
fi

# Store original content for comparison
ORIGINAL_CONTENT=$(cat "$DOCKERFILE_PATH")

# Process each version mapping
UPDATES_MADE=0
echo ""
echo "Processing version mappings:"

while IFS= read -r mapping; do
    # Skip empty lines and comments
    [[ -z "$mapping" || "$mapping" =~ ^[[:space:]]*# ]] && continue
    
    # Parse mapping format: image:old_version->new_version
    if [[ "$mapping" =~ ^([^:]+):([^-]+)->(.+)$ ]]; then
        IMAGE="${BASH_REMATCH[1]}"
        OLD_VERSION="${BASH_REMATCH[2]}"
        NEW_VERSION="${BASH_REMATCH[3]}"
        
        echo "  Processing: $IMAGE:$OLD_VERSION → $IMAGE:$NEW_VERSION"
        
        # Check if the old version exists in the Dockerfile
        if grep -q "FROM $IMAGE:$OLD_VERSION" "$DOCKERFILE_PATH"; then
            # Perform the replacement
            sed -i "s/FROM $IMAGE:$OLD_VERSION/FROM $IMAGE:$NEW_VERSION/g" "$DOCKERFILE_PATH"
            echo "    ✓ Updated $IMAGE from $OLD_VERSION to $NEW_VERSION"
            ((UPDATES_MADE++))
        else
            echo "    - No $IMAGE:$OLD_VERSION found in Dockerfile"
        fi
    else
        echo "  Warning: Invalid mapping format: $mapping"
        echo "    Expected format: image:old_version->new_version"
    fi
done <<< "$MAPPINGS"

echo ""
echo "Update Summary:"
echo "==============="
echo "Total mappings processed: $(echo "$MAPPINGS" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | wc -l)"
echo "Updates applied: $UPDATES_MADE"

# Show differences if requested and changes were made
if [ "$SHOW_DIFF" = "true" ] && [ $UPDATES_MADE -gt 0 ]; then
    echo ""
    echo "Changes made to $DOCKERFILE_PATH:"
    echo "=================================="
    
    if command -v diff > /dev/null && [ "$BACKUP_FILES" = "true" ]; then
        # Use backup file for diff if available
        diff "$BACKUP_PATH" "$DOCKERFILE_PATH" || true
    else
        # Compare with original content
        echo "$ORIGINAL_CONTENT" | diff - "$DOCKERFILE_PATH" || true
    fi
fi

# Show current FROM lines
echo ""
echo "Current FROM statements in $DOCKERFILE_PATH:"
echo "============================================="
grep "^FROM " "$DOCKERFILE_PATH" || echo "No FROM statements found"

# Validate Dockerfile syntax if docker is available
if command -v docker > /dev/null 2>&1; then
    echo ""
    echo "Validating Dockerfile syntax..."
    if docker build -f "$DOCKERFILE_PATH" -t validation-test --dry-run . > /dev/null 2>&1; then
        echo "✓ Dockerfile syntax is valid"
    else
        echo "⚠ Warning: Dockerfile may have syntax issues"
        echo "Run 'docker build -f $DOCKERFILE_PATH -t test .' to check manually"
    fi
fi

if [ $UPDATES_MADE -eq 0 ]; then
    echo ""
    echo "✅ No updates were needed - all images are already using target versions"
    exit 1  # Exit with 1 to indicate no changes (useful for CI/CD conditionals)
else
    echo ""
    echo "✅ Successfully updated $UPDATES_MADE Docker base image(s)"
    exit 0
fi