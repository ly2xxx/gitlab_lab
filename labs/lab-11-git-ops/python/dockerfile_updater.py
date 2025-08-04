#!/usr/bin/env python3
"""
Dockerfile updater for GitLab CI/CD pipeline.
Updates Docker base images in Dockerfiles with latest versions.
"""

import re
import os
import logging
from typing import Dict, List, Optional, Tuple
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from utils import Config, check_file_exists, print_subsection
from docker_image_checker import DockerImageChecker, ImageConfig


class DockerfileUpdater:
    """Update Docker base images in Dockerfiles."""
    
    def __init__(self, config: Config):
        """Initialize the updater with configuration."""
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.checker = DockerImageChecker(config)
    
    def read_dockerfile(self) -> Optional[str]:
        """Read the current Dockerfile content."""
        try:
            with open(self.config.dockerfile_path, 'r') as f:
                content = f.read()
            self.logger.debug(f"Read Dockerfile: {len(content)} characters")
            return content
        except FileNotFoundError:
            self.logger.error(f"Dockerfile not found: {self.config.dockerfile_path}")
            return None
        except Exception as e:
            self.logger.error(f"Error reading Dockerfile: {e}")
            return None
    
    def write_dockerfile(self, content: str) -> bool:
        """Write content to the Dockerfile."""
        try:
            with open(self.config.dockerfile_path, 'w') as f:
                f.write(content)
            self.logger.info(f"Dockerfile updated: {self.config.dockerfile_path}")
            return True
        except Exception as e:
            self.logger.error(f"Error writing Dockerfile: {e}")
            return False
    
    def backup_dockerfile(self) -> bool:
        """Create a backup of the current Dockerfile."""
        backup_path = f"{self.config.dockerfile_path}.backup"
        try:
            content = self.read_dockerfile()
            if content is None:
                return False
            
            with open(backup_path, 'w') as f:
                f.write(content)
            
            self.logger.info(f"Dockerfile backed up to: {backup_path}")
            return True
        except Exception as e:
            self.logger.error(f"Error creating backup: {e}")
            return False
    
    def show_dockerfile_content(self, title: str) -> None:
        """Display current Dockerfile content with a title."""
        content = self.read_dockerfile()
        if content:
            print(f"=== Dockerfile content {title} ===")
            print(content)
            print(f"=== END {title} ===")
    
    def get_current_image_version(self, image_name: str) -> Optional[str]:
        """Get current version of a specific image from Dockerfile."""
        content = self.read_dockerfile()
        if not content:
            return None
        
        # Look for FROM statements with the specified image
        pattern = rf"FROM {re.escape(image_name)}:([^\s]+)"
        match = re.search(pattern, content)
        
        if match:
            return match.group(1)
        
        return None
    
    def update_image_version(self, image_name: str, new_version: str, show_detailed: bool = False) -> bool:
        """
        Update a specific image version in the Dockerfile.
        
        Args:
            image_name: Name of the Docker image to update
            new_version: New version to update to
            show_detailed: Whether to show detailed before/after content
            
        Returns:
            True if update was successful, False otherwise
        """
        content = self.read_dockerfile()
        if not content:
            return False
        
        # Get current version
        current_version = self.get_current_image_version(image_name)
        if not current_version:
            self.logger.warning(f"No {image_name} image found in Dockerfile")
            return False
        
        if current_version == new_version:
            self.logger.info(f"{image_name} is already at version {new_version}")
            return True  # Not an error, just no change needed
        
        if show_detailed:
            self.show_dockerfile_content("BEFORE update")
        
        # Escape special regex characters
        escaped_current = re.escape(current_version)
        escaped_new = re.escape(new_version)
        
        # Perform the replacement
        pattern = rf"FROM {re.escape(image_name)}:{escaped_current}"
        replacement = f"FROM {image_name}:{new_version}"
        
        self.logger.info(f"Updating {image_name} from {current_version} to {new_version}")
        new_content = re.sub(pattern, replacement, content)
        
        # Verify the change was made
        if new_content == content:
            self.logger.error(f"No changes made to Dockerfile for {image_name}")
            return False
        
        # Write the updated content
        if not self.write_dockerfile(new_content):
            return False
        
        if show_detailed:
            self.show_dockerfile_content("AFTER update")
        
        # Verify the update was successful
        updated_version = self.get_current_image_version(image_name)
        if updated_version == new_version:
            print(f"✓ {image_name} base image successfully updated to {new_version}")
            return True
        else:
            print(f"✗ ERROR: {image_name} base image update failed")
            # Show what we actually have
            if updated_version:
                print(f"Found version: {updated_version}, expected: {new_version}")
            else:
                print(f"No {image_name} FROM line found after update")
            return False
    
    def update_all_images(self, show_detailed: bool = False) -> Tuple[bool, List[str]]:
        """
        Update all configured Docker images to their latest versions.
        
        Args:
            show_detailed: Whether to show detailed output for the first image
            
        Returns:
            Tuple of (success, list of updated images)
        """
        if not check_file_exists(self.config.dockerfile_path, required=False):
            self.logger.error("Dockerfile not found for updates")
            return False, []
        
        print("Current branch:", os.popen('git branch --show-current').read().strip())
        print("Current Dockerfile content:")
        content = self.read_dockerfile()
        if content:
            print(content)
        
        # Create backup
        if not self.backup_dockerfile():
            self.logger.warning("Failed to create backup, continuing anyway")
        
        updated_images = []
        overall_success = True
        
        for i, image_config in enumerate(DockerImageChecker.IMAGE_CONFIGS):
            try:
                print_subsection(f"Updating {image_config.display_name}")
                
                # Get latest version for this image
                tags = self.checker._fetch_docker_tags(image_config.name)
                if not tags:
                    print(f"Could not fetch tags for {image_config.display_name}, skipping")
                    continue
                
                latest_tag = self.checker._filter_and_sort_tags(
                    tags, image_config.tag_filter, image_config.sort_method
                )
                if not latest_tag:
                    print(f"Could not determine latest tag for {image_config.display_name}, skipping")
                    continue
                
                # Show detailed output for first image only (matching original behavior)
                detailed = show_detailed and i == 0
                
                # Update the image
                success = self.update_image_version(
                    image_config.name, 
                    latest_tag, 
                    show_detailed=detailed
                )
                
                if success:
                    updated_images.append(f"{image_config.name}:{latest_tag}")
                else:
                    overall_success = False
                    
            except Exception as e:
                self.logger.error(f"Error updating {image_config.display_name}: {e}")
                overall_success = False
                continue
        
        # Show final result
        print("\nUpdated Dockerfile content:")
        final_content = self.read_dockerfile()
        if final_content:
            print(final_content)
        
        return overall_success, updated_images
    
    def has_changes(self) -> bool:
        """Check if there are any changes in the git working directory."""
        try:
            import subprocess
            result = subprocess.run(['git', 'diff', '--quiet'], capture_output=True)
            # git diff --quiet returns 0 if no changes, 1 if changes exist
            return result.returncode != 0
        except Exception as e:
            self.logger.error(f"Error checking for git changes: {e}")
            return False
    
    def get_dockerfile_diff(self) -> Optional[str]:
        """Get the diff of Dockerfile changes."""
        backup_path = f"{self.config.dockerfile_path}.backup"
        
        if not os.path.exists(backup_path):
            self.logger.warning("No backup file found for diff")
            return None
        
        try:
            import subprocess
            result = subprocess.run(
                ['diff', backup_path, self.config.dockerfile_path],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                return "No changes detected"
            else:
                return result.stdout
                
        except Exception as e:
            self.logger.error(f"Error getting diff: {e}")
            return None


def main():
    """Main function for standalone execution."""
    import sys
    from utils import setup_logging, EnvironmentManager, exit_with_message
    
    setup_logging()
    
    config = Config()
    if not config.validate():
        exit_with_message("Configuration validation failed", 1)
    
    updater = DockerfileUpdater(config)
    
    # Check if updates are needed first
    if not EnvironmentManager.get_updates_needed():
        print("✅ No Docker image updates needed - skipping Dockerfile updates")
        return 0
    
    # Update all images
    success, updated_images = updater.update_all_images(show_detailed=True)
    
    if updated_images:
        print(f"\n✓ Successfully updated {len(updated_images)} images:")
        for image in updated_images:
            print(f"  - {image}")
        
        # Check if we have git changes
        if updater.has_changes():
            print("Changes detected in Dockerfile")
            EnvironmentManager.set_changes_made(True)
        else:
            print("No changes made to Dockerfile")
            EnvironmentManager.set_changes_made(False)
    else:
        print("No images were updated")
        EnvironmentManager.set_changes_made(False)
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())