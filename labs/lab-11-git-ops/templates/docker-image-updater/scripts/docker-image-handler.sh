#!/bin/bash
# Docker Image Handler Script
# Extracted from GitLab CI pipeline for component reusability
# Handles Docker Hub API queries and Dockerfile updates

set -e

# Function to handle Docker image updates via API
handle_docker_image() {
  local image_name="$1"
  local tag_filter="$2"
  local sort_method="$3"
  local display_name="$4"
  local mode="$5"           # "check" or "update"
  local show_detailed="$6"  # "true" or "false"
  local dockerfile_path="${7:-Dockerfile}"
  
  echo "$([ "$mode" = "check" ] && echo "Checking for" || echo "Querying Docker Hub API for latest") $display_name $([ "$mode" = "check" ] && echo "updates..." || echo "image...")"
  local response=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/$image_name/tags/?page_size=100")
  
  if [ $? -eq 0 ] && [ -n "$response" ]; then
    # Extract tags based on filter pattern
    local latest_tag=$(echo "$response" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | grep -E "$tag_filter" | sort $sort_method | tail -1)
    
    if [ -n "$latest_tag" ]; then
      echo "Latest $display_name tag $([ "$mode" = "check" ] && echo "available" || echo "found") - $latest_tag"
      
      # Check current version in Dockerfile (if it exists)
      if [ -f "$dockerfile_path" ]; then
        local current_version=$(grep -oE "FROM $image_name:[^[:space:]]+" "$dockerfile_path" | sed "s/FROM $image_name://" || echo "")
        
        if [ -n "$current_version" ]; then
          echo "Current $display_name version - $current_version"
          
          if [ "$current_version" != "$latest_tag" ]; then
            if [ "$mode" = "check" ]; then
              echo "✓ Update available - $image_name:$current_version → $image_name:$latest_tag"
              return 0  # Update needed
            else
              echo "Updating $display_name base image from $image_name:$current_version to $image_name:$latest_tag"
              
              # Show detailed output if requested
              if [ "$show_detailed" = "true" ]; then
                echo "=== Dockerfile content BEFORE update ==="
                cat "$dockerfile_path"
                echo "=== END BEFORE ==="
              fi
              
              # Escape special characters and perform replacement
              local escaped_current=$(echo "$current_version" | sed 's/[[\.*^$()+?{|]/\\&/g')
              local escaped_new=$(echo "$latest_tag" | sed 's/[[\.*^$()+?{|]/\\&/g')
              
              echo "Executing sed command for $display_name update"
              sed -i "s/FROM $image_name:$escaped_current/FROM $image_name:$escaped_new/g" "$dockerfile_path"
              
              # Show detailed output if requested
              if [ "$show_detailed" = "true" ]; then
                echo "=== Dockerfile content AFTER update ==="
                cat "$dockerfile_path"
                echo "=== END AFTER ==="
              fi
              
              # Verify the change was made
              if grep -q "FROM $image_name:$latest_tag" "$dockerfile_path"; then
                echo "✓ $display_name base image successfully updated to $latest_tag"
                return 0  # Update successful
              else
                echo "✗ ERROR: $display_name base image update failed"
                grep "FROM $image_name:" "$dockerfile_path" || echo "No $display_name FROM line found"
                return 1  # Update failed
              fi
            fi
          else
            echo "$([ "$mode" = "check" ] && echo "- No update needed" || echo "- Already latest") - $image_name:$current_version $([ "$mode" = "check" ] && echo "is already latest" || echo "")"
            return 1  # No update needed
          fi
        else
          echo "$([ "$mode" = "check" ] && echo "- No" || echo "No") $display_name base image found in Dockerfile"
          return 1  # No update needed
        fi
      else
        if [ "$mode" = "check" ]; then
          echo "- No Dockerfile found, will need to create sample files"
          return 0  # Update needed (file creation)
        else
          echo "No Dockerfile found at $dockerfile_path"
          return 1  # Cannot update without Dockerfile
        fi
      fi
    else
      echo "Could not parse $display_name tags from API response"
      return 1  # No update needed (API issue)
    fi
  else
    echo "Could not fetch $display_name tags from Docker Hub API$([ "$mode" = "check" ] && echo "" || echo ", keeping current version")"
    return 1  # No update needed (API issue)
  fi
}

# Function to process multiple images from input string
process_docker_images() {
  local images_config="$1"
  local mode="$2"
  local show_detailed="$3"
  local dockerfile_path="$4"
  local updates_needed=false
  
  echo "$images_config" | while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Parse format: image_name:tag_filter:sort_method:display_name
    IFS=':' read -r image_name tag_filter sort_method display_name <<< "$line"
    
    if [ -n "$image_name" ] && [ -n "$tag_filter" ] && [ -n "$sort_method" ] && [ -n "$display_name" ]; then
      if handle_docker_image "$image_name" "$tag_filter" "$sort_method" "$display_name" "$mode" "$show_detailed" "$dockerfile_path"; then
        updates_needed=true
      fi
    fi
  done
  
  return $([ "$updates_needed" = "true" ] && echo 0 || echo 1)
}

# Main execution if script is called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
  # Default configuration if no arguments provided
  DEFAULT_IMAGES="python:^[0-9]+\.[0-9]+(\.[0-9]+)?-slim$:-V:Python slim
node:^[0-9]+$:-n:Node.js LTS
alpine:^[0-9]+\.[0-9]+(\.[0-9]+)?$:-V:Alpine"

  MODE="${1:-check}"
  IMAGES_CONFIG="${2:-$DEFAULT_IMAGES}"
  SHOW_DETAILED="${3:-false}"
  DOCKERFILE_PATH="${4:-Dockerfile}"
  
  echo "Docker Image Handler - Mode: $MODE"
  echo "Processing images: $(echo "$IMAGES_CONFIG" | wc -l) image(s)"
  
  if process_docker_images "$IMAGES_CONFIG" "$MODE" "$SHOW_DETAILED" "$DOCKERFILE_PATH"; then
    echo "Updates available or processing completed successfully"
    exit 0
  else
    echo "No updates needed or processing failed"
    exit 1
  fi
fi