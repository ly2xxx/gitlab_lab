#!/usr/bin/env python3
"""
Docker image checker for GitLab CI/CD pipeline.
Queries Docker Hub API to check for latest image versions.
"""

import re
import json
import logging
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from urllib.request import urlopen
from urllib.error import URLError, HTTPError
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from utils import Config, exit_with_message, print_subsection


@dataclass
class ImageConfig:
    """Configuration for a Docker image to check."""
    name: str
    tag_filter: str
    sort_method: str
    display_name: str
    
    def __post_init__(self):
        """Validate sort method."""
        if self.sort_method not in ['-V', '-n']:
            raise ValueError(f"Invalid sort method: {self.sort_method}. Must be '-V' or '-n'")


class DockerImageChecker:
    """Check Docker images for updates using Docker Hub API."""
    
    # Predefined image configurations matching the original shell script
    IMAGE_CONFIGS = [
        ImageConfig(
            name="python",
            tag_filter=r"^[0-9]+\.[0-9]+(\.[0-9]+)?-slim$",
            sort_method="-V",
            display_name="Python slim"
        ),
        # ImageConfig(
        #     name="node", 
        #     tag_filter=r"^[0-9]+$",
        #     sort_method="-n",
        #     display_name="Node.js LTS"
        # ),
        # ImageConfig(
        #     name="alpine",
        #     tag_filter=r"^[0-9]+\.[0-9]+(\.[0-9]+)?$",
        #     sort_method="-V", 
        #     display_name="Alpine"
        # )
    ]
    
    def __init__(self, config: Config):
        """Initialize the checker with configuration."""
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    def _fetch_docker_tags(self, image_name: str) -> Optional[List[str]]:
        """Fetch tags for a Docker image from Docker Hub API."""
        url = f"https://registry.hub.docker.com/v2/repositories/library/{image_name}/tags/?page_size=100"
        
        try:
            self.logger.debug(f"Fetching tags from: {url}")
            with urlopen(url, timeout=30) as response:
                data = json.loads(response.read().decode())
                
                if 'results' not in data:
                    self.logger.error(f"Unexpected API response format for {image_name}")
                    return None
                
                tags = [result['name'] for result in data['results']]
                self.logger.debug(f"Found {len(tags)} tags for {image_name}")
                return tags
                
        except (URLError, HTTPError) as e:
            self.logger.error(f"Failed to fetch tags for {image_name}: {e}")
            return None
        except json.JSONDecodeError as e:
            self.logger.error(f"Failed to parse JSON response for {image_name}: {e}")
            return None
    
    def _filter_and_sort_tags(self, tags: List[str], tag_filter: str, sort_method: str) -> Optional[str]:
        """Filter tags by pattern and return the latest according to sort method."""
        if not tags:
            return None
        
        # Filter tags using regex
        pattern = re.compile(tag_filter)
        filtered_tags = [tag for tag in tags if pattern.match(tag)]
        
        if not filtered_tags:
            self.logger.warning(f"No tags matched filter pattern: {tag_filter}")
            return None
        
        self.logger.debug(f"Filtered tags: {filtered_tags[:10]}...")  # Show first 10 for debug
        
        # Sort based on method
        if sort_method == "-V":
            # Version sort (semantic versioning)
            filtered_tags.sort(key=self._version_key)
        elif sort_method == "-n":
            # Numeric sort
            filtered_tags.sort(key=lambda x: int(x) if x.isdigit() else 0)
        
        latest_tag = filtered_tags[-1] if filtered_tags else None
        self.logger.debug(f"Latest tag after sorting: {latest_tag}")
        
        return latest_tag
    
    def _version_key(self, version: str) -> Tuple:
        """Create a tuple for version comparison."""
        # Extract version parts, handling suffixes like '-slim'
        version_part = version.split('-')[0]  # Remove suffixes like '-slim'
        parts = []
        
        for part in version_part.split('.'):
            try:
                parts.append(int(part))
            except ValueError:
                # Handle non-numeric parts
                parts.append(0)
        
        return tuple(parts)
    
    def _get_current_image_version(self, image_name: str) -> Optional[str]:
        """Get current image version from Dockerfile."""
        try:
            with open(self.config.dockerfile_path, 'r') as f:
                content = f.read()
            
            # Look for FROM statements with the specified image
            pattern = rf"FROM {re.escape(image_name)}:([^\s]+)"
            match = re.search(pattern, content)
            
            if match:
                current_version = match.group(1)
                self.logger.debug(f"Current {image_name} version: {current_version}")
                return current_version
            
            self.logger.debug(f"No {image_name} image found in Dockerfile")
            return None
            
        except FileNotFoundError:
            self.logger.warning(f"Dockerfile not found: {self.config.dockerfile_path}")
            return None
        except Exception as e:
            self.logger.error(f"Error reading Dockerfile: {e}")
            return None
    
    def check_image_update(self, image_config: ImageConfig, mode: str = "check") -> bool:
        """
        Check if an image needs updating.
        
        Args:
            image_config: Configuration for the image to check
            mode: "check" or "update" mode
            
        Returns:
            True if update is needed/available, False otherwise
        """
        print_subsection(f"{'Checking' if mode == 'check' else 'Querying'} {image_config.display_name}")
        
        # Fetch tags from Docker Hub
        tags = self._fetch_docker_tags(image_config.name)
        if not tags:
            print(f"Could not fetch {image_config.display_name} tags from Docker Hub API")
            return False
        
        # Find latest tag
        latest_tag = self._filter_and_sort_tags(tags, image_config.tag_filter, image_config.sort_method)
        if not latest_tag:
            print(f"Could not parse {image_config.display_name} tags from API response")
            return False
        
        print(f"Latest {image_config.display_name} tag {'available' if mode == 'check' else 'found'} - {latest_tag}")
        
        # Check current version
        current_version = self._get_current_image_version(image_config.name)
        
        if not current_version:
            if mode == "check":
                print(f"- No {image_config.display_name} base image found in Dockerfile")
                return False
            else:
                print(f"No {image_config.display_name} base image found in Dockerfile")
                return False
        
        print(f"Current {image_config.display_name} version - {current_version}")
        
        # Compare versions
        if current_version != latest_tag:
            if mode == "check":
                print(f"✓ Update available - {image_config.name}:{current_version} → {image_config.name}:{latest_tag}")
                return True
            else:
                print(f"Update needed - {image_config.name}:{current_version} → {image_config.name}:{latest_tag}")
                return True
        else:
            print(f"{'- No update needed' if mode == 'check' else '- Already latest'} - {image_config.name}:{current_version} {'is already latest' if mode == 'check' else ''}")
            return False
    
    def check_all_updates(self) -> bool:
        """
        Check all configured images for updates.
        
        Returns:
            True if any updates are needed, False otherwise
        """
        updates_needed = False
        
        print("Checking for Docker image updates...")
        
        for image_config in self.IMAGE_CONFIGS:
            try:
                if self.check_image_update(image_config, mode="check"):
                    updates_needed = True
            except Exception as e:
                self.logger.error(f"Error checking {image_config.display_name}: {e}")
                # Continue checking other images
                continue
        
        return updates_needed
    
    def get_update_info(self) -> Dict[str, Dict[str, str]]:
        """
        Get detailed update information for all images.
        
        Returns:
            Dictionary with image update information
        """
        update_info = {}
        
        for image_config in self.IMAGE_CONFIGS:
            try:
                tags = self._fetch_docker_tags(image_config.name)
                if tags:
                    latest_tag = self._filter_and_sort_tags(tags, image_config.tag_filter, image_config.sort_method)
                    current_version = self._get_current_image_version(image_config.name)
                    
                    update_info[image_config.name] = {
                        'display_name': image_config.display_name,
                        'current_version': current_version or 'unknown',
                        'latest_version': latest_tag or 'unknown',
                        'update_needed': current_version != latest_tag if current_version and latest_tag else False
                    }
            except Exception as e:
                self.logger.error(f"Error getting update info for {image_config.display_name}: {e}")
                update_info[image_config.name] = {
                    'display_name': image_config.display_name,
                    'current_version': 'error',
                    'latest_version': 'error',
                    'update_needed': False
                }
        
        return update_info


def main():
    """Main function for standalone execution."""
    import sys
    from utils import setup_logging, EnvironmentManager
    
    setup_logging()
    
    config = Config()
    if not config.validate():
        exit_with_message("Configuration validation failed", 1)
    
    checker = DockerImageChecker(config)
    
    # Check for updates
    updates_needed = checker.check_all_updates()
    
    # Output results
    print("\n")
    if updates_needed:
        print("🔄 Docker image updates are available - pipeline will continue")
        EnvironmentManager.set_updates_needed(True)
    else:
        print("✅ All Docker images are up to date - skipping remaining jobs")
        EnvironmentManager.set_updates_needed(False)
    
    return 0 if updates_needed else 1


if __name__ == "__main__":
    sys.exit(main())