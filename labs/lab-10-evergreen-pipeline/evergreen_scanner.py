#!/usr/bin/env python3
"""
Evergreen CI/CD Pipeline Scanner
A simplified dependency update system for GitLab repositories
Similar to Renovate but focused on Dockerfile dependencies

Author: GitLab Lab Tutorial
License: MIT
"""

import os
import re
import sys
import json
import logging
import requests
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from urllib.parse import urlparse
import gitlab
from gitlab.exceptions import GitlabError


# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class DockerImage:
    """Represents a Docker image with name and tag"""
    name: str
    tag: str
    registry: Optional[str] = None
    
    def __str__(self):
        if self.registry:
            return f"{self.registry}/{self.name}:{self.tag}"
        return f"{self.name}:{self.tag}"


@dataclass
class UpdateCandidate:
    """Represents a potential update for a Docker image"""
    current_image: DockerImage
    latest_image: DockerImage
    dockerfile_path: str
    line_number: int


class DockerHubAPI:
    """Interface to Docker Hub API for version checking"""
    
    BASE_URL = "https://registry.hub.docker.com/v2"
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Evergreen-Scanner/1.0'
        })
    
    def get_latest_tag(self, image_name: str) -> Optional[str]:
        """Get the latest tag for a Docker image from Docker Hub"""
        try:
            # Handle official images (no namespace)
            if '/' not in image_name:
                repo_name = f"library/{image_name}"
            else:
                repo_name = image_name
            
            # Get tags from Docker Hub API
            url = f"{self.BASE_URL}/repositories/{repo_name}/tags"
            params = {
                'page_size': 100,
                'ordering': 'last_updated'
            }
            
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            tags = data.get('results', [])
            
            # Filter out non-semantic version tags and find latest
            semantic_tags = []
            for tag_info in tags:
                tag_name = tag_info['name']
                if self._is_semantic_version(tag_name):
                    semantic_tags.append(tag_name)
            
            if semantic_tags:
                # Return the most recent semantic version
                return self._get_latest_semantic_version(semantic_tags)
            
            # Fallback to 'latest' tag if available
            for tag_info in tags:
                if tag_info['name'] == 'latest':
                    return 'latest'
            
            return None
            
        except requests.RequestException as e:
            logger.warning(f"Failed to fetch tags for {image_name}: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error fetching tags for {image_name}: {e}")
            return None
    
    def _is_semantic_version(self, tag: str) -> bool:
        """Check if a tag follows semantic versioning"""
        # Match patterns like: 1.2.3, v1.2.3, 1.2, 1.2.3-alpine, etc.
        pattern = r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:-[\w\.-]+)?$'
        return bool(re.match(pattern, tag))
    
    def _get_latest_semantic_version(self, tags: List[str]) -> str:
        """Get the latest semantic version from a list of tags"""
        def version_key(tag: str):
            # Extract version numbers for comparison
            match = re.match(r'^v?(\d+)\.(\d+)(?:\.(\d+))?', tag)
            if match:
                major = int(match.group(1))
                minor = int(match.group(2))
                patch = int(match.group(3) or 0)
                return (major, minor, patch)
            return (0, 0, 0)
        
        return max(tags, key=version_key)


class DockerfileParser:
    """Parse Dockerfiles to extract image dependencies"""
    
    @staticmethod
    def parse_dockerfile(content: str) -> List[DockerImage]:
        """Parse Dockerfile content and extract FROM statements"""
        images = []
        lines = content.split('\n')
        
        for line in lines:
            line = line.strip()
            if line.startswith('FROM '):
                image = DockerfileParser._parse_from_statement(line)
                if image:
                    images.append(image)
        
        return images
    
    @staticmethod
    def _parse_from_statement(from_line: str) -> Optional[DockerImage]:
        """Parse a FROM statement to extract image information"""
        # Remove 'FROM ' prefix and handle AS clause
        image_part = from_line[5:].strip()
        
        # Handle multi-stage builds (FROM image AS stage)
        if ' AS ' in image_part.upper():
            image_part = image_part.split(' AS ')[0].strip()
        
        # Skip scratch and build args
        if image_part.lower() in ['scratch'] or image_part.startswith('$'):
            return None
        
        # Parse registry/namespace/image:tag
        if '/' in image_part and image_part.count('/') >= 2:
            # Full registry path
            parts = image_part.split('/')
            registry = parts[0]
            name = '/'.join(parts[1:-1]) + '/' + parts[-1].split(':')[0]
            tag = parts[-1].split(':')[1] if ':' in parts[-1] else 'latest'
            return DockerImage(name=name, tag=tag, registry=registry)
        else:
            # Docker Hub image
            if ':' in image_part:
                name, tag = image_part.rsplit(':', 1)
            else:
                name, tag = image_part, 'latest'
            
            return DockerImage(name=name, tag=tag)


class GitLabEvergreenScanner:
    """Main scanner class for GitLab evergreen updates"""
    
    def __init__(self, gitlab_url: str, access_token: str, project_path: str):
        """Initialize the scanner with GitLab configuration"""
        self.gitlab_url = gitlab_url
        self.access_token = access_token
        self.project_path = project_path
        
        # Initialize GitLab API client
        self.gl = gitlab.Gitlab(gitlab_url, private_token=access_token)
        self.project = None
        self.docker_api = DockerHubAPI()
        
        # Configuration
        self.branch_prefix = "evergreen/"
        self.dockerfile_patterns = ["Dockerfile*", "*.dockerfile", "docker/Dockerfile*"]
        
    def authenticate(self) -> bool:
        """Authenticate with GitLab and get project"""
        try:
            self.gl.auth()
            self.project = self.gl.projects.get(self.project_path)
            logger.info(f"Successfully authenticated with GitLab project: {self.project.name}")
            return True
        except GitlabError as e:
            logger.error(f"GitLab authentication failed: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected authentication error: {e}")
            return False
    
    def scan_dockerfiles(self) -> List[UpdateCandidate]:
        """Scan all Dockerfiles in the repository for updates"""
        update_candidates = []
        
        try:
            # Get all files in the repository
            items = self._get_all_repository_files()
            dockerfiles = self._filter_dockerfiles(items)
            
            logger.info(f"Found {len(dockerfiles)} Dockerfile(s) to scan")
            
            for dockerfile_path in dockerfiles:
                candidates = self._scan_dockerfile(dockerfile_path)
                update_candidates.extend(candidates)
            
        except Exception as e:
            logger.error(f"Error scanning Dockerfiles: {e}")
        
        return update_candidates
    
    def _get_all_repository_files(self) -> List[str]:
        """Get list of all files in the repository"""
        files = []
        
        def collect_files(items, path_prefix=""):
            for item in items:
                full_path = f"{path_prefix}/{item['name']}" if path_prefix else item['name']
                if item['type'] == 'blob':  # file
                    files.append(full_path)
                elif item['type'] == 'tree':  # directory
                    try:
                        sub_items = self.project.repository_tree(path=full_path, recursive=False)
                        collect_files(sub_items, full_path)
                    except GitlabError:
                        # Skip directories we can't access
                        pass
        
        root_items = self.project.repository_tree(recursive=False)
        collect_files(root_items)
        
        return files
    
    def _filter_dockerfiles(self, files: List[str]) -> List[str]:
        """Filter files to find Dockerfiles"""
        dockerfiles = []
        
        for file_path in files:
            filename = os.path.basename(file_path).lower()
            
            # Check against patterns
            if (filename == 'dockerfile' or 
                filename.startswith('dockerfile.') or
                filename.endswith('.dockerfile')):
                dockerfiles.append(file_path)
        
        return dockerfiles
    
    def _scan_dockerfile(self, dockerfile_path: str) -> List[UpdateCandidate]:
        """Scan a specific Dockerfile for updates"""
        update_candidates = []
        
        try:
            # Get file content
            file_content = self.project.files.get(dockerfile_path, ref='main')
            content = file_content.decode().decode('utf-8')
            
            # Parse images
            images = DockerfileParser.parse_dockerfile(content)
            
            logger.info(f"Found {len(images)} images in {dockerfile_path}")
            
            # Check each image for updates
            for i, image in enumerate(images):
                if self._should_check_image(image):
                    latest_tag = self.docker_api.get_latest_tag(image.name)
                    
                    if latest_tag and latest_tag != image.tag:
                        latest_image = DockerImage(
                            name=image.name,
                            tag=latest_tag,
                            registry=image.registry
                        )
                        
                        candidate = UpdateCandidate(
                            current_image=image,
                            latest_image=latest_image,
                            dockerfile_path=dockerfile_path,
                            line_number=i + 1  # Approximate line number
                        )
                        
                        update_candidates.append(candidate)
                        logger.info(f"Update found: {image} -> {latest_image}")
        
        except Exception as e:
            logger.error(f"Error scanning {dockerfile_path}: {e}")
        
        return update_candidates
    
    def _should_check_image(self, image: DockerImage) -> bool:
        """Determine if an image should be checked for updates"""
        # Skip images with 'latest' tag (already latest)
        if image.tag == 'latest':
            return False
        
        # Skip private registries for now (would need authentication)
        if image.registry and 'docker.io' not in image.registry:
            return False
        
        return True
    
    def create_update_branch_and_mr(self, candidate: UpdateCandidate) -> bool:
        """Create a feature branch and merge request for an update"""
        try:
            branch_name = f"{self.branch_prefix}{candidate.current_image.name.replace('/', '-')}-{candidate.latest_image.tag}"
            
            # Check if branch already exists
            try:
                existing_branch = self.project.branches.get(branch_name)
                logger.info(f"Branch {branch_name} already exists, skipping")
                return False
            except GitlabError:
                # Branch doesn't exist, which is what we want
                pass
            
            # Create new branch from main
            self.project.branches.create({'branch': branch_name, 'ref': 'main'})
            logger.info(f"Created branch: {branch_name}")
            
            # Update the Dockerfile
            self._update_dockerfile(candidate, branch_name)
            
            # Create merge request
            mr_title = f"Update {candidate.current_image.name} from {candidate.current_image.tag} to {candidate.latest_image.tag}"
            mr_description = f"""
## Automated Dependency Update

This merge request updates the Docker image dependency:

- **Image**: {candidate.current_image.name}
- **Current Version**: {candidate.current_image.tag}
- **New Version**: {candidate.latest_image.tag}
- **File**: {candidate.dockerfile_path}

This update was automatically generated by the Evergreen Scanner.

### Checklist
- [ ] Review the changelog for breaking changes
- [ ] Update any related documentation
- [ ] Test the changes in a development environment

---
*Generated by Evergreen Scanner*
"""
            
            mr = self.project.mergerequests.create({
                'source_branch': branch_name,
                'target_branch': 'main',
                'title': mr_title,
                'description': mr_description,
                'labels': ['evergreen', 'dependencies', 'automated']
            })
            
            logger.info(f"Created merge request: {mr.web_url}")
            return True
            
        except Exception as e:
            logger.error(f"Error creating update branch/MR: {e}")
            return False
    
    def _update_dockerfile(self, candidate: UpdateCandidate, branch_name: str):
        """Update the Dockerfile with the new image version"""
        try:
            # Get current file content
            file_obj = self.project.files.get(candidate.dockerfile_path, ref='main')
            content = file_obj.decode().decode('utf-8')
            
            # Replace the image reference
            old_image_ref = str(candidate.current_image)
            new_image_ref = str(candidate.latest_image)
            
            updated_content = content.replace(old_image_ref, new_image_ref)
            
            # Commit the changes
            commit_message = f"Update {candidate.current_image.name} to {candidate.latest_image.tag}"
            
            file_obj.content = updated_content
            file_obj.save(branch=branch_name, commit_message=commit_message)
            
            logger.info(f"Updated {candidate.dockerfile_path} in branch {branch_name}")
            
        except Exception as e:
            logger.error(f"Error updating Dockerfile: {e}")
            raise


def main():
    """Main entry point for the evergreen scanner"""
    # Get configuration from environment variables
    gitlab_url = os.getenv('GITLAB_URL', 'https://gitlab.com')
    access_token = os.getenv('GITLAB_ACCESS_TOKEN')
    project_path = os.getenv('GITLAB_PROJECT_PATH')
    
    if not access_token:
        logger.error("GITLAB_ACCESS_TOKEN environment variable is required")
        sys.exit(1)
    
    if not project_path:
        logger.error("GITLAB_PROJECT_PATH environment variable is required")
        sys.exit(1)
    
    logger.info("Starting Evergreen Scanner...")
    logger.info(f"GitLab URL: {gitlab_url}")
    logger.info(f"Project Path: {project_path}")
    
    # Initialize scanner
    scanner = GitLabEvergreenScanner(gitlab_url, access_token, project_path)
    
    # Authenticate
    if not scanner.authenticate():
        logger.error("Authentication failed")
        sys.exit(1)
    
    # Scan for updates
    update_candidates = scanner.scan_dockerfiles()
    
    if not update_candidates:
        logger.info("No updates found")
        return
    
    logger.info(f"Found {len(update_candidates)} potential updates")
    
    # Create branches and MRs for each update
    success_count = 0
    for candidate in update_candidates:
        if scanner.create_update_branch_and_mr(candidate):
            success_count += 1
    
    logger.info(f"Successfully created {success_count} merge requests")


if __name__ == "__main__":
    main()
