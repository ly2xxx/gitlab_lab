#!/usr/bin/env python3
"""
GitLab API operations for CI/CD pipeline.
Handles merge request creation and other GitLab API interactions.
"""

import json
import logging
from typing import Dict, Any, Optional
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from utils import Config, exit_with_message, print_subsection, EnvironmentManager


class GitLabAPI:
    """Handle GitLab API operations."""
    
    def __init__(self, config: Config):
        """Initialize GitLab API client with configuration."""
        self.config = config
        self.logger = logging.getLogger(__name__)
        
        if not config.access_token:
            raise ValueError("ACCESS_TOKEN is required for GitLab API operations")
        if not config.ci_api_v4_url:
            raise ValueError("CI_API_V4_URL is required for GitLab API operations")
        if not config.ci_project_id:
            raise ValueError("CI_PROJECT_ID is required for GitLab API operations")
    
    def _make_request(self, method: str, endpoint: str, data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Make a request to the GitLab API.
        
        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: API endpoint (relative to projects/{id}/)
            data: Request data for POST/PUT requests
            
        Returns:
            JSON response as dictionary
        """
        url = f"{self.config.ci_api_v4_url}/projects/{self.config.ci_project_id}/{endpoint}"
        
        headers = {
            'PRIVATE-TOKEN': self.config.access_token,
            'Content-Type': 'application/json'
        }
        
        request_data = None
        if data:
            request_data = json.dumps(data).encode('utf-8')
        
        self.logger.debug(f"Making {method} request to: {url}")
        
        try:
            request = Request(url, data=request_data, headers=headers, method=method)
            
            with urlopen(request, timeout=30) as response:
                response_data = response.read().decode('utf-8')
                
                if response_data:
                    return json.loads(response_data)
                else:
                    return {}
                    
        except HTTPError as e:
            error_msg = f"GitLab API HTTP error: {e.code} {e.reason}"
            try:
                error_response = e.read().decode('utf-8')
                error_data = json.loads(error_response)
                error_msg += f" - {error_data}"
            except:
                pass
            
            self.logger.error(error_msg)
            raise Exception(error_msg)
            
        except URLError as e:
            error_msg = f"GitLab API URL error: {e.reason}"
            self.logger.error(error_msg)
            raise Exception(error_msg)
            
        except json.JSONDecodeError as e:
            error_msg = f"GitLab API JSON decode error: {e}"
            self.logger.error(error_msg)
            raise Exception(error_msg)
    
    def create_merge_request(self, source_branch: str, target_branch: str, 
                           title: str, description: str, 
                           remove_source_branch: bool = True) -> Dict[str, Any]:
        """
        Create a merge request.
        
        Args:
            source_branch: Source branch name
            target_branch: Target branch name
            title: MR title
            description: MR description
            remove_source_branch: Whether to remove source branch after merge
            
        Returns:
            Created merge request data
        """
        data = {
            'source_branch': source_branch,
            'target_branch': target_branch,
            'title': title,
            'description': description,
            'remove_source_branch': remove_source_branch
        }
        
        self.logger.info(f"Creating merge request: {source_branch} -> {target_branch}")
        
        return self._make_request('POST', 'merge_requests', data)
    
    def get_merge_requests(self, state: str = 'opened', 
                          source_branch: Optional[str] = None) -> Dict[str, Any]:
        """
        Get merge requests for the project.
        
        Args:
            state: MR state (opened, closed, merged, all)
            source_branch: Filter by source branch
            
        Returns:
            List of merge requests
        """
        endpoint = f'merge_requests?state={state}'
        if source_branch:
            endpoint += f'&source_branch={source_branch}'
        
        return self._make_request('GET', endpoint)
    
    def get_project_info(self) -> Dict[str, Any]:
        """
        Get project information.
        
        Returns:
            Project data
        """
        return self._make_request('GET', '')
    
    def check_branch_exists(self, branch_name: str) -> bool:
        """
        Check if a branch exists in the project.
        
        Args:
            branch_name: Name of the branch to check
            
        Returns:
            True if branch exists, False otherwise
        """
        try:
            self._make_request('GET', f'repository/branches/{branch_name}')
            return True
        except Exception:
            return False


def create_automated_merge_request():
    """Create an automated merge request for Docker image updates."""
    import sys
    from utils import setup_logging
    
    setup_logging()
    
    config = Config()
    if not config.validate():
        exit_with_message("Configuration validation failed", 1)
    
    # Check if changes were actually made
    if not EnvironmentManager.get_changes_made():
        print("✅ No changes were made - skipping commit and merge request creation")
        return 0
    
    # Check if feature branch was created
    feature_branch = EnvironmentManager.get_feature_branch()
    if not feature_branch:
        print("❌ No feature branch was created - cannot proceed with merge request")
        return 1
    
    try:
        gitlab_api = GitLabAPI(config)
        
        print_subsection(f"Creating Merge Request")
        print(f"🔄 Creating merge request for {feature_branch} -> {config.base_branch}")
        
        # Create the merge request
        title = "chore: update Docker base images (automated)"
        description = f"""This merge request was automatically created by GitLab CI/CD pipeline {config.ci_pipeline_id}.

## Changes Made
- Updated Docker base image versions in Dockerfiles

## Automated Updates
This MR contains automated updates to keep our Docker base images current with the latest stable versions:

- **Python**: Updated to latest slim version
- **Node.js**: Updated to latest LTS version  
- **Alpine**: Updated to latest stable version

## Review Notes
Please review the Dockerfile changes to ensure compatibility with your application before merging.

---
*🤖 This merge request was created automatically by the GitLab CI/CD pipeline.*
"""
        
        mr_data = gitlab_api.create_merge_request(
            source_branch=feature_branch,
            target_branch=config.base_branch,
            title=title,
            description=description,
            remove_source_branch=True
        )
        
        print(f"✅ Merge request created successfully!")
        print(f"   - Title: {title}")
        print(f"   - Source: {feature_branch}")
        print(f"   - Target: {config.base_branch}")
        print(f"   - MR ID: {mr_data.get('iid', 'unknown')}")
        print(f"   - URL: {mr_data.get('web_url', 'unknown')}")
        
        # Log additional details
        logging.info(f"Merge request created: {mr_data.get('web_url', 'unknown')}")
        
        return 0
        
    except Exception as e:
        logging.error(f"Failed to create merge request: {e}")
        print(f"❌ Failed to create merge request: {e}")
        return 1


def list_merge_requests():
    """List current merge requests (utility function)."""
    import sys
    from utils import setup_logging
    
    setup_logging()
    
    config = Config()
    if not config.validate():
        exit_with_message("Configuration validation failed", 1)
    
    try:
        gitlab_api = GitLabAPI(config)
        
        print("Fetching merge requests...")
        mrs = gitlab_api.get_merge_requests(state='opened')
        
        if not mrs:
            print("No open merge requests found.")
            return 0
        
        print(f"\nFound {len(mrs)} open merge request(s):")
        for mr in mrs:
            print(f"  - #{mr['iid']}: {mr['title']}")
            print(f"    {mr['source_branch']} -> {mr['target_branch']}")
            print(f"    URL: {mr['web_url']}")
            print()
        
        return 0
        
    except Exception as e:
        logging.error(f"Failed to list merge requests: {e}")
        print(f"❌ Failed to list merge requests: {e}")
        return 1


def check_project_access():
    """Check if we can access the GitLab project (utility function)."""
    import sys
    from utils import setup_logging
    
    setup_logging()
    
    config = Config()
    if not config.validate():
        exit_with_message("Configuration validation failed", 1)
    
    try:
        gitlab_api = GitLabAPI(config)
        
        project_info = gitlab_api.get_project_info()
        
        print("✅ GitLab API access successful!")
        print(f"   - Project: {project_info.get('name', 'unknown')}")
        print(f"   - ID: {project_info.get('id', 'unknown')}")
        print(f"   - URL: {project_info.get('web_url', 'unknown')}")
        print(f"   - Default branch: {project_info.get('default_branch', 'unknown')}")
        
        return 0
        
    except Exception as e:
        logging.error(f"Failed to access GitLab project: {e}")
        print(f"❌ Failed to access GitLab project: {e}")
        return 1


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "create-mr":
            sys.exit(create_automated_merge_request())
        elif command == "list-mrs":
            sys.exit(list_merge_requests())
        elif command == "check-access":
            sys.exit(check_project_access())
    
    print("Usage: gitlab_api.py [create-mr|list-mrs|check-access]")
    sys.exit(1)