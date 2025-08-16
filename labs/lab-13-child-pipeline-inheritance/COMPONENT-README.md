# Child Pipeline Inheritance Component

A reusable GitLab CI component that provides dynamic child pipeline generation with inheritance capabilities. This component enables projects to automatically generate and execute child pipelines based on repository changes.

## Features

- 🔧 **Dynamic Pipeline Generation**: Automatically creates child pipelines based on detected changes
- 🎨 **Multi-Technology Support**: Detects frontend, backend, and infrastructure changes
- 📊 **Java-style Logging**: Standardized colored logging with ERROR, WARN, INFO, DEBUG levels
- ⚙️ **Configurable Stages**: Customizable pipeline stages and job execution
- 🚀 **Production Deployment**: Automatic production deployment detection for main branches
- 📋 **Inheritance**: Child pipelines inherit variables and configuration from parent

## Quick Start

### Basic Usage

Add this component to your `.gitlab-ci.yml`:

```yaml
include:
  - component: $CI_SERVER_FQDN/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME/child-pipeline-inheritance@main

stages:
  - validate
  - build
  - maintenance
```

### Advanced Configuration

```yaml
include:
  - component: $CI_SERVER_FQDN/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME/child-pipeline-inheritance@main
    inputs:
      stage: "build"
      enable_backend_build: "true"
      enable_validation: "true"
      docker_image: "ubuntu:22.04"
      component_stages: "validate,build,test,deploy"

stages:
  - validate
  - build
  - test
  - deploy
```

## Configuration Inputs

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `stage` | Pipeline stage for child pipeline jobs | `"maintenance"` | No |
| `enable_backend_build` | Enable backend build job | `"true"` | No |
| `enable_validation` | Enable syntax validation job | `"true"` | No |
| `docker_image` | Docker image for pipeline generation | `"ubuntu:latest"` | No |
| `component_stages` | Comma-separated stages to add | `"validate,build,maintenance"` | No |

## Generated Child Pipeline Features

The component automatically detects repository changes and generates appropriate jobs:

### Frontend Detection
- **Triggers**: `frontend/` directory, `*.html`, `*.css`, `*.js` files, `package.json`
- **Generated Jobs**: 
  - `dynamic-build-frontend`: Builds frontend components
  - `dynamic-test-frontend`: Runs frontend tests

### Backend Detection  
- **Triggers**: `backend/` directory, `*.py`, `*.java`, `*.go` files, `requirements.txt`, `pom.xml`
- **Generated Jobs**:
  - `dynamic-build-backend`: Builds backend services
  - `dynamic-test-backend`: Runs API and database tests

### Infrastructure Detection
- **Triggers**: `infrastructure/` directory, `Dockerfile*`, `docker-compose*.yml`, `kubernetes/`, `terraform/`
- **Generated Jobs**:
  - `dynamic-build-infrastructure`: Validates infrastructure configurations
  - `dynamic-deploy-infrastructure`: Deploys infrastructure changes

### Production Deployment
- **Triggers**: Main branch commits (`main`, `master`, `$CI_DEFAULT_BRANCH`)
- **Generated Jobs**:
  - `dynamic-deploy-production`: Manual production deployment with environment

## Logging System

The component includes a standardized Java-style logging system:

```bash
# Available in all jobs via eval "$ECHO_FUNCTIONS"
log_error "Error message"    # Red with ❌ emoji
log_warn "Warning message"   # Yellow with ⚠️ emoji  
log_info "Info message"      # Green with ℹ️ emoji
log_debug "Debug message"    # Blue with 🔍 emoji
```

### Example Output
```
[INFO] ℹ️ 🚀 Pipeline started - ID- 12345
[DEBUG] 🔍 Working directory- /builds/project
[WARN] ⚠️ No previous commit to compare
[ERROR] ❌ Build failed
```

## Component Jobs

### 1. component-validate-syntax
- **Stage**: First stage from `component_stages`
- **Purpose**: Validates YAML syntax and checks for required files
- **Triggers**: When `enable_validation` is `"true"`

### 2. component-backend-build  
- **Stage**: Second stage from `component_stages` (default: "build")
- **Purpose**: Builds backend API components
- **Triggers**: When `enable_backend_build` is `"true"` and backend changes detected

### 3. component-generate-child-pipeline
- **Stage**: Last stage from `component_stages` (default: "maintenance")
- **Purpose**: Generates dynamic child pipeline configuration
- **Artifacts**: `generated-child-pipeline.yml`

### 4. component-trigger-dynamic-child
- **Stage**: Last stage from `component_stages` (default: "maintenance")  
- **Purpose**: Triggers the generated child pipeline
- **Dependencies**: Requires `component-generate-child-pipeline` artifacts

## Project Structure Requirements

For optimal functionality, organize your project as follows:

```
your-project/
├── .gitlab-ci.yml          # Include the component here
├── frontend/               # Frontend code (triggers frontend jobs)
│   ├── app.js
│   ├── index.html
│   └── styles.css
├── backend/                # Backend code (triggers backend jobs)
│   ├── app.py
│   └── requirements.txt
├── infrastructure/         # Infrastructure code (triggers infra jobs)
│   ├── Dockerfile
│   └── docker-compose.yml
└── package.json           # Also triggers frontend jobs
```

## Environment Variables

The following variables are available in child pipelines:

- `PARENT_PIPELINE_ID`: ID of the parent pipeline
- `CHILD_TYPE`: Set to `"dynamic"`
- `CHILD_PIPELINE_TYPE`: Set to `"dynamic"`
- `GENERATION_TIME`: ISO timestamp of when the pipeline was generated
- `ECHO_FUNCTIONS`: Logging functions for standardized output

## Example Usage in Dependent Project

Create a `.gitlab-ci.yml` in your project:

```yaml
# Include the child pipeline inheritance component
include:
  - component: gitlab.example.com/cicd-components/child-pipeline-inheritance@1.0.0
    inputs:
      stage: "maintenance"
      enable_backend_build: "true"
      enable_validation: "true"

# Define your project stages
stages:
  - validate
  - build
  - test
  - maintenance

# Your project-specific jobs
custom-job:
  stage: test
  script:
    - eval "$ECHO_FUNCTIONS"  # Use component logging
    - log_info "Running custom project tests"
    - echo "Custom test logic here"
```

The component will automatically:
1. Add validation and backend build jobs to your pipeline
2. Generate a child pipeline based on detected changes
3. Trigger the child pipeline with inheritance from the parent
4. Provide standardized logging across all jobs

## Troubleshooting

### Child Pipeline Not Generated
- Ensure the component is included correctly in your `.gitlab-ci.yml`
- Check that you have the required stages defined
- Verify `enable_validation` and other inputs are set correctly

### Missing Dependencies
- The component requires `ubuntu:latest` or compatible image with `bash` and `git`
- `dos2unix` is automatically installed during pipeline generation

### Artifact Issues
- Child pipeline generation creates `generated-child-pipeline.yml` artifact
- Ensure the trigger job has proper `needs` dependency on the generation job

## Version History

- **v1.0.0**: Initial component release with dynamic pipeline generation
- Includes standardized logging, multi-technology detection, and production deployment

## License

This component is part of the GitLab CI/CD Labs collection and follows the same licensing terms as the parent project.