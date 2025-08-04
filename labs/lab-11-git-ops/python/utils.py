#!/usr/bin/env python3
"""
Common utilities and configuration for GitLab CI/CD Docker image update pipeline.
"""

import os
import sys
import logging
from typing import Dict, Any, Optional


class Config:
    """Configuration management for the pipeline."""
    
    def __init__(self):
        """Initialize configuration from environment variables."""
        self.ci_pipeline_id = os.getenv('CI_PIPELINE_ID', 'unknown')
        self.ci_project_id = os.getenv('CI_PROJECT_ID')
        self.ci_project_url = os.getenv('CI_PROJECT_URL')
        self.ci_api_v4_url = os.getenv('CI_API_V4_URL')
        self.ci_commit_branch = os.getenv('CI_COMMIT_BRANCH', 'main')
        self.gitlab_user_email = os.getenv('GITLAB_USER_EMAIL', 'ci@example.com')
        self.gitlab_user_name = os.getenv('GITLAB_USER_NAME', 'GitLab CI')
        self.access_token = os.getenv('ACCESS_TOKEN')
        
        # Pipeline-specific configuration
        self.feature_branch = os.getenv('FEATURE_BRANCH', f'feature/update-base-images-{self.ci_pipeline_id}')
        self.base_branch = os.getenv('BASE_BRANCH', 'main')
        
        # File paths
        self.dockerfile_path = 'sample-app/Dockerfile'
        self.sample_app_dir = 'sample-app'
        self.scripts_dir = 'scripts'
    
    def validate(self) -> bool:
        """Validate required configuration."""
        required_vars = []
        
        if not self.access_token:
            required_vars.append('ACCESS_TOKEN')
        if not self.ci_project_id:
            required_vars.append('CI_PROJECT_ID')
        if not self.ci_project_url:
            required_vars.append('CI_PROJECT_URL')
        if not self.ci_api_v4_url:
            required_vars.append('CI_API_V4_URL')
        
        if required_vars:
            logging.error(f"Missing required environment variables: {', '.join(required_vars)}")
            return False
        
        return True
    
    def get_repo_url(self) -> str:
        """Get authenticated repository URL."""
        if not self.ci_project_url or not self.access_token:
            raise ValueError("CI_PROJECT_URL and ACCESS_TOKEN are required")
        
        return self.ci_project_url.replace('://', f'://oauth2:{self.access_token}@')


def setup_logging(level: str = 'INFO') -> None:
    """Setup logging configuration."""
    log_level = getattr(logging, level.upper(), logging.INFO)
    
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def write_env_file(filename: str, variables: Dict[str, Any]) -> None:
    """Write environment variables to a file for GitLab CI artifacts."""
    try:
        with open(filename, 'w') as f:
            for key, value in variables.items():
                f.write(f"{key}={value}\n")
        logging.info(f"Environment variables written to {filename}")
    except Exception as e:
        logging.error(f"Failed to write environment file {filename}: {e}")
        raise


def read_env_file(filename: str) -> Dict[str, str]:
    """Read environment variables from a file."""
    variables = {}
    try:
        if os.path.exists(filename):
            with open(filename, 'r') as f:
                for line in f:
                    line = line.strip()
                    if '=' in line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        variables[key] = value
    except Exception as e:
        logging.warning(f"Failed to read environment file {filename}: {e}")
    
    return variables


def exit_with_message(message: str, exit_code: int = 0) -> None:
    """Exit with a message and specified exit code."""
    if exit_code == 0:
        logging.info(message)
    else:
        logging.error(message)
    
    print(message)
    sys.exit(exit_code)


def check_file_exists(filepath: str, required: bool = True) -> bool:
    """Check if a file exists, optionally exit if required."""
    exists = os.path.exists(filepath)
    
    if required and not exists:
        exit_with_message(f"Required file not found: {filepath}", 1)
    
    return exists


def ensure_directory(directory: str) -> None:
    """Ensure a directory exists, create if it doesn't."""
    try:
        os.makedirs(directory, exist_ok=True)
        logging.debug(f"Directory ensured: {directory}")
    except Exception as e:
        logging.error(f"Failed to create directory {directory}: {e}")
        raise


class EnvironmentManager:
    """Manage environment variables and artifacts for pipeline stages."""
    
    @staticmethod
    def set_updates_needed(updates_needed: bool) -> None:
        """Set the UPDATES_NEEDED environment variable."""
        write_env_file('updates.env', {'UPDATES_NEEDED': str(updates_needed).lower()})
    
    @staticmethod
    def set_changes_made(changes_made: bool) -> None:
        """Set the CHANGES_MADE environment variable."""
        write_env_file('changes.env', {'CHANGES_MADE': str(changes_made).lower()})
    
    @staticmethod
    def set_feature_branch(branch_name: str) -> None:
        """Set the FEATURE_BRANCH environment variable."""
        write_env_file('branch.env', {'FEATURE_BRANCH': branch_name})
    
    @staticmethod
    def get_updates_needed() -> bool:
        """Get the UPDATES_NEEDED value from environment or file."""
        # First check environment variable
        env_value = os.getenv('UPDATES_NEEDED')
        if env_value:
            return env_value.lower() == 'true'
        
        # Fall back to reading from file
        env_vars = read_env_file('updates.env')
        return env_vars.get('UPDATES_NEEDED', 'false').lower() == 'true'
    
    @staticmethod
    def get_changes_made() -> bool:
        """Get the CHANGES_MADE value from environment or file."""
        # First check environment variable
        env_value = os.getenv('CHANGES_MADE')
        if env_value:
            return env_value.lower() == 'true'
        
        # Fall back to reading from file
        env_vars = read_env_file('changes.env')
        return env_vars.get('CHANGES_MADE', 'false').lower() == 'true'
    
    @staticmethod
    def get_feature_branch() -> Optional[str]:
        """Get the FEATURE_BRANCH value from environment or file."""
        # First check environment variable
        env_value = os.getenv('FEATURE_BRANCH')
        if env_value:
            return env_value
        
        # Fall back to reading from file
        env_vars = read_env_file('branch.env')
        branch = env_vars.get('FEATURE_BRANCH')
        return branch if branch else None


def print_section(title: str) -> None:
    """Print a formatted section header."""
    print(f"\n{'='*60}")
    print(f" {title}")
    print(f"{'='*60}")


def print_subsection(title: str) -> None:
    """Print a formatted subsection header."""
    print(f"\n--- {title} ---")