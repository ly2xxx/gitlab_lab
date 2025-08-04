#!/usr/bin/env python3
"""
Git operations for GitLab CI/CD pipeline.
Handles branch creation, authentication, commits, and pushes.
"""

import os
import logging
import subprocess
from typing import Optional, List
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from utils import Config, exit_with_message, print_subsection, EnvironmentManager


class GitOperations:
    """Handle git operations for the CI/CD pipeline."""
    
    def __init__(self, config: Config):
        """Initialize git operations with configuration."""
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    def run_git_command(self, args: List[str], check: bool = True, capture_output: bool = False) -> subprocess.CompletedProcess:
        """
        Run a git command with proper error handling.
        
        Args:
            args: Git command arguments (without 'git')
            check: Whether to raise exception on non-zero exit code
            capture_output: Whether to capture stdout/stderr
            
        Returns:
            CompletedProcess result
        """
        cmd = ['git'] + args
        self.logger.debug(f"Running git command: {' '.join(cmd)}")
        
        try:
            result = subprocess.run(
                cmd,
                check=check,
                capture_output=capture_output,
                text=True
            )
            return result
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Git command failed: {' '.join(cmd)}")
            self.logger.error(f"Exit code: {e.returncode}")
            if capture_output:
                self.logger.error(f"Stdout: {e.stdout}")
                self.logger.error(f"Stderr: {e.stderr}")
            raise
    
    def configure_git_user(self) -> None:
        """Configure git user email and name."""
        print_subsection("Configuring Git User")
        
        self.run_git_command(['config', '--global', 'user.email', self.config.gitlab_user_email])
        self.run_git_command(['config', '--global', 'user.name', self.config.gitlab_user_name])
        self.run_git_command(['config', '--global', 'init.defaultBranch', 'main'])
        
        print(f"Git configured - User: {self.config.gitlab_user_name} <{self.config.gitlab_user_email}>")
        
        self.logger.info("Git user configuration completed")
    
    def setup_repository_authentication(self) -> None:
        """Setup repository with authentication token."""
        print_subsection("Setting up Repository Authentication")
        
        repo_url = self.config.get_repo_url()
        print(f"Repository URL configured - {self.config.ci_project_url}")
        
        self.run_git_command(['remote', 'set-url', 'origin', repo_url])
        self.run_git_command(['fetch', 'origin'])
        
        print("Repository authentication configured")
        self.logger.info("Repository authentication setup completed")
    
    def create_feature_branch(self) -> str:
        """
        Create and push a new feature branch.
        
        Returns:
            The name of the created branch
        """
        print_subsection(f"Creating Feature Branch")
        
        branch_name = self.config.feature_branch
        print(f"Creating feature branch {branch_name}")
        
        # Create and checkout the new branch from base branch
        self.run_git_command([
            'checkout', '-b', branch_name, f'origin/{self.config.base_branch}'
        ])
        
        # Push the branch with ci.skip to avoid triggering another pipeline
        self.run_git_command([
            'push', '-u', 'origin', branch_name, '-o', 'ci.skip'
        ])
        
        print(f"Feature branch created: {branch_name}")
        self.logger.info(f"Feature branch created and pushed: {branch_name}")
        
        return branch_name
    
    def check_for_changes(self) -> bool:
        """
        Check if there are any staged or unstaged changes.
        
        Returns:
            True if changes exist, False otherwise
        """
        try:
            # Check for unstaged changes
            result = self.run_git_command(['diff', '--quiet'], check=False, capture_output=True)
            has_unstaged = result.returncode != 0
            
            # Check for staged changes
            result = self.run_git_command(['diff', '--staged', '--quiet'], check=False, capture_output=True)
            has_staged = result.returncode != 0
            
            return has_unstaged or has_staged
        except Exception as e:
            self.logger.error(f"Error checking for changes: {e}")
            return False
    
    def stage_all_changes(self) -> None:
        """Stage all changes in the repository."""
        self.run_git_command(['add', '.'])
        self.logger.info("All changes staged")
    
    def check_staged_changes(self) -> bool:
        """
        Check if there are any staged changes ready to commit.
        
        Returns:
            True if staged changes exist, False otherwise
        """
        try:
            result = self.run_git_command(['diff', '--staged', '--quiet'], check=False, capture_output=True)
            return result.returncode != 0
        except Exception as e:
            self.logger.error(f"Error checking staged changes: {e}")
            return False
    
    def commit_changes(self, message: str) -> bool:
        """
        Commit staged changes with the provided message.
        
        Args:
            message: Commit message
            
        Returns:
            True if commit was successful, False otherwise
        """
        try:
            self.run_git_command(['commit', '-m', message])
            print("Changes committed successfully")
            return True
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to commit changes: {e}")
            return False
    
    def push_changes(self, branch_name: Optional[str] = None) -> bool:
        """
        Push changes to the remote repository.
        
        Args:
            branch_name: Branch to push (defaults to current branch)
            
        Returns:
            True if push was successful, False otherwise
        """
        try:
            if branch_name:
                self.run_git_command(['push', 'origin', branch_name, '-o', 'ci.skip'])
            else:
                self.run_git_command(['push', '-o', 'ci.skip'])
            
            print(f"Changes pushed to {'branch ' + branch_name if branch_name else 'remote'}")
            return True
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to push changes: {e}")
            return False
    
    def get_current_branch(self) -> Optional[str]:
        """
        Get the name of the current branch.
        
        Returns:
            Current branch name or None if error
        """
        try:
            result = self.run_git_command(['branch', '--show-current'], capture_output=True)
            return result.stdout.strip()
        except Exception as e:
            self.logger.error(f"Error getting current branch: {e}")
            return None
    
    def delete_remote_branch(self, branch_name: str) -> bool:
        """
        Delete a remote branch.
        
        Args:
            branch_name: Name of the branch to delete
            
        Returns:
            True if deletion was successful, False otherwise
        """
        try:
            self.run_git_command(['push', 'origin', '--delete', branch_name])
            print(f"Remote branch {branch_name} deleted")
            return True
        except subprocess.CalledProcessError as e:
            print(f"Branch {branch_name} may not exist or already deleted")
            self.logger.warning(f"Failed to delete remote branch {branch_name}: {e}")
            return False
    
    def cleanup_artifact_files(self) -> None:
        """Clean up any artifact files that might conflict with git operations."""
        artifact_files = ['branch.env', 'changes.env', 'updates.env']
        
        for file in artifact_files:
            if os.path.exists(file):
                try:
                    os.remove(file)
                    self.logger.debug(f"Removed artifact file: {file}")
                except Exception as e:
                    self.logger.warning(f"Failed to remove artifact file {file}: {e}")
    
    def get_git_status(self) -> str:
        """
        Get the current git status.
        
        Returns:
            Git status output
        """
        try:
            result = self.run_git_command(['status', '--porcelain'], capture_output=True)
            return result.stdout
        except Exception as e:
            self.logger.error(f"Error getting git status: {e}")
            return ""


def setup_and_update():
    """Main function for setup-and-update stage."""
    import sys
    from utils import setup_logging
    sys.path.insert(0, os.path.dirname(__file__))
    from dockerfile_updater import DockerfileUpdater
    from file_creator import FileCreator
    
    setup_logging()
    
    config = Config()
    if not config.validate():
        exit_with_message("Configuration validation failed", 1)
    
    git_ops = GitOperations(config)
    
    # Check if updates are needed
    if not EnvironmentManager.get_updates_needed():
        print("✅ No Docker image updates needed - skipping branch creation and updates")
        EnvironmentManager.set_changes_made(False)
        EnvironmentManager.set_feature_branch("")
        return 0
    
    try:
        # Clean up any artifact files that might conflict
        git_ops.cleanup_artifact_files()
        
        # Setup git configuration and authentication
        git_ops.configure_git_user()
        git_ops.setup_repository_authentication()
        
        # Create feature branch
        branch_name = git_ops.create_feature_branch()
        EnvironmentManager.set_feature_branch(branch_name)
        
        # Update Docker images
        if os.path.exists(config.dockerfile_path):
            updater = DockerfileUpdater(config)
            success, updated_images = updater.update_all_images(show_detailed=True)
            
            if not success:
                print("Warning: Some image updates failed, but continuing...")
        else:
            print("No Dockerfile found, creating sample files")
            file_creator = FileCreator(config)
            file_creator.create_all_sample_files()
        
        # Stage and check for changes
        git_ops.stage_all_changes()
        
        if git_ops.check_staged_changes():
            print("Changes staged successfully")
            EnvironmentManager.set_changes_made(True)
            
            # Commit the changes
            commit_message = f"""chore: update Docker base images

- Updated Python base image version
- Updated Node.js base image version  
- Updated Alpine base image version

Automated update via GitLab CI Pipeline {config.ci_pipeline_id}"""
            
            print("Committing Dockerfile changes in update job")
            if git_ops.commit_changes(commit_message):
                # Push the changes
                if git_ops.push_changes(branch_name):
                    print(f"Changes committed and pushed to {branch_name}")
                else:
                    print("Failed to push changes")
                    return 1
            else:
                print("Failed to commit changes")
                return 1
        else:
            print("No staged changes to commit")
            EnvironmentManager.set_changes_made(False)
        
        return 0
        
    except Exception as e:
        logging.error(f"Setup and update failed: {e}")
        return 1


def cleanup_on_failure():
    """Cleanup function for pipeline failures."""
    import sys
    from utils import setup_logging
    
    setup_logging()
    
    config = Config()
    git_ops = GitOperations(config)
    
    try:
        git_ops.configure_git_user()
        git_ops.setup_repository_authentication()
        
        branch_name = EnvironmentManager.get_feature_branch()
        if branch_name:
            print(f"Cleaning up feature branch {branch_name} due to pipeline failure")
            git_ops.delete_remote_branch(branch_name)
        else:
            print("No feature branch to clean up")
            
    except Exception as e:
        logging.error(f"Cleanup on failure error: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "setup":
            sys.exit(setup_and_update())
        elif sys.argv[1] == "cleanup":
            sys.exit(cleanup_on_failure())
    
    print("Usage: git_operations.py [setup|cleanup]")
    sys.exit(1)