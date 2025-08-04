# Python Scripts for GitLab CI/CD Pipeline

This directory contains Python scripts that replace the complex shell scripts in the original `.gitlab-ci.yml` file, providing better maintainability, testability, and error handling.

## Scripts Overview

### Core Pipeline Scripts

**`utils.py`** - Common utilities and configuration
- Configuration management from environment variables
- Environment file handling for GitLab CI artifacts
- Logging setup and utilities
- Path and file management helpers

**`docker_image_checker.py`** - Docker Hub API integration
- Queries Docker Hub API for latest image versions
- Supports filtering by tag patterns (slim, LTS, version numbers)
- Compares current vs latest versions in Dockerfiles
- Generates environment variables for pipeline decisions

**`dockerfile_updater.py`** - Dockerfile parsing and updating
- Parses and updates Dockerfile FROM statements
- Supports multiple image types (Python, Node.js, Alpine)
- Provides detailed logging of changes made
- Validates that updates were successful

**`git_operations.py`** - Git branch and commit operations
- Handles git configuration, authentication, and remote setup
- Creates and manages feature branches
- Commits and pushes changes with proper messaging
- Cleans up branches on pipeline failure

**`gitlab_api.py`** - GitLab API for merge requests
- Creates merge requests via GitLab API
- Handles API authentication and error handling
- Formats MR titles and descriptions
- Includes utility functions for project access

**`file_creator.py`** - Sample file creation
- Creates sample application files when needed
- Replaces the functionality of `create-sample-files.sh`
- Ensures consistent file structure

## Usage

### Pipeline Usage

Use the `.gitlab-ci-python.yml` file instead of the original `.gitlab-ci.yml`:

```bash
# Copy the Python CI configuration
cp .gitlab-ci-python.yml .gitlab-ci.yml
git add .gitlab-ci.yml
git commit -m "Switch to Python-based CI pipeline"
git push
```

### Local Testing

Test individual scripts locally:

```bash
# Test Docker image checking
python3 python/docker_image_checker.py

# Test file creation
python3 python/file_creator.py

# Test GitLab API access (requires ACCESS_TOKEN)
python3 python/gitlab_api.py check-access

# Validate all Python syntax
python3 -m py_compile python/*.py
```

### Environment Variables

The scripts use the same environment variables as the original shell-based pipeline:

**Required:**
- `ACCESS_TOKEN` - GitLab access token for API operations
- `CI_PROJECT_ID` - GitLab project ID
- `CI_PROJECT_URL` - GitLab project URL
- `CI_API_V4_URL` - GitLab API v4 URL

**Optional:**
- `GITLAB_USER_EMAIL` - Git commit author email (default: ci@example.com)
- `GITLAB_USER_NAME` - Git commit author name (default: GitLab CI)
- `FEATURE_BRANCH` - Feature branch name (default: feature/update-base-images-{pipeline_id})
- `BASE_BRANCH` - Target branch (default: main)

## Benefits Over Shell Scripts

### Maintainability
- **Clear separation of concerns**: Each script has a specific responsibility
- **Modular design**: Functions can be imported and reused
- **Type hints**: Better code documentation and IDE support
- **Error handling**: Proper exception handling with detailed error messages

### Testability
- **Unit testable**: Individual functions can be tested in isolation
- **Mockable**: External dependencies (APIs, git commands) can be mocked
- **Debuggable**: Easier to debug locally with Python debugger
- **Syntax validation**: Python syntax can be validated before execution

### Reliability
- **Better error messages**: More descriptive error reporting
- **Graceful degradation**: Handles API failures and network issues
- **Input validation**: Validates configuration and environment variables
- **Logging**: Comprehensive logging for troubleshooting

### Features
- **Progress indication**: Clear progress messages and section headers
- **Detailed output**: Optional verbose output for debugging
- **Artifact management**: Proper handling of GitLab CI artifacts
- **Configuration management**: Centralized configuration handling

## Script Dependencies

The scripts have minimal external dependencies:
- **Python 3.11+** (specified in CI configuration)
- **requests** - For HTTP API calls (installed in CI)
- **Standard library modules** - json, logging, os, subprocess, etc.

No additional packages are required for basic functionality.

## Pipeline Flow

1. **check-updates** stage:
   - Runs `docker_image_checker.py`
   - Queries Docker Hub API for latest versions
   - Sets `UPDATES_NEEDED` environment variable

2. **setup-and-update** stage:
   - Runs `git_operations.py setup`
   - Creates feature branch if updates needed
   - Updates Dockerfiles using `dockerfile_updater.py`
   - Commits and pushes changes
   - Sets `CHANGES_MADE` and `FEATURE_BRANCH` variables

3. **commit-and-merge-request** stage:
   - Runs `gitlab_api.py create-mr`
   - Creates merge request if changes were made
   - Links to the automated update pipeline

4. **cleanup-on-failure** stage:
   - Runs `git_operations.py cleanup`
   - Cleans up feature branches on pipeline failure

## Debugging

### Common Issues

**Import errors**: Make sure you're running from the correct directory
```bash
cd /path/to/lab-11-git-ops
python3 python/script_name.py
```

**API errors**: Check that ACCESS_TOKEN and other CI variables are set
```bash
python3 python/gitlab_api.py check-access
```

**Git errors**: Verify git configuration and repository access
```bash
git config --list
```

### Verbose Logging

Enable debug logging by modifying the script:
```python
from utils import setup_logging
setup_logging('DEBUG')  # Instead of 'INFO'
```

## Testing in GitLab CI

The `.gitlab-ci-python.yml` includes several manual jobs for testing:

- `test-python-scripts` - Basic import and functionality tests
- `validate-python-code` - Python syntax validation
- `show-current-versions` - Display current Docker image versions
- `list-merge-requests` - Show current merge requests

These can be triggered manually from the GitLab CI/CD pipeline interface.