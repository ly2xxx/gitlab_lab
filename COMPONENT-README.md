# Child Pipeline Inheritance Component

A reusable GitLab CI/CD component that provides dynamic child pipeline generation with inheritance capabilities and standardized logging.

## 🚀 Features

- **Dynamic Pipeline Generation**: Automatically creates child pipelines based on repository changes
- **Java-style Logging**: Standardized colored logging with ERROR, WARN, INFO, DEBUG levels
- **Multi-Technology Detection**: Supports frontend, backend, and infrastructure changes
- **Variable Inheritance**: Child pipelines inherit variables and context from parent
- **Configurable Execution**: Customizable stages and conditional job execution
- **Production Deployment**: Automatic production deployment detection for main branches

## 📋 Quick Start

### Basic Usage

Include this component in your `.gitlab-ci.yml`:

```yaml
include:
  - component: $CI_SERVER_FQDN/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME/child-pipeline-inheritance@v1.0.0

stages:
  - maintenance

variables:
  PROJECT_NAME: "my-project"
```

### Advanced Configuration

```yaml
include:
  - component: $CI_SERVER_FQDN/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME/child-pipeline-inheritance@v1.0.0
    inputs:
      stage: "build"
      enable_backend_build: "true"
      enable_validation: "true"
      docker_image: "ubuntu:22.04"

stages:
  - validate
  - build
  - deploy
```

## ⚙️ Configuration

### Input Parameters

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `stage` | Pipeline stage where component jobs run | `"maintenance"` | No |
| `enable_backend_build` | Enable backend build job | `"true"` | No |
| `enable_validation` | Enable syntax validation job | `"true"` | No |
| `docker_image` | Container image for pipeline generation | `"ubuntu:latest"` | No |

### Component Jobs

The component adds these jobs to your pipeline:

1. **component-validate-syntax**: Validates YAML and performs basic checks
2. **component-backend-build**: Builds backend API when changes detected
3. **component-generate-child-pipeline**: Creates dynamic child pipeline configuration
4. **component-trigger-dynamic-child**: Triggers the generated child pipeline

## 🔧 Child Pipeline Features

The generated child pipeline automatically detects repository changes and creates appropriate jobs:

### Frontend Detection
- **Triggers**: `frontend/` directory, `*.html`, `*.css`, `*.js` files, `package.json`
- **Jobs**: `dynamic-build-frontend`, `dynamic-test-frontend`

### Backend Detection  
- **Triggers**: `backend/` directory, `*.py`, `*.java`, `*.go` files, `requirements.txt`, `pom.xml`
- **Jobs**: `dynamic-build-backend`, `dynamic-test-backend`

### Infrastructure Detection
- **Triggers**: `Dockerfile*`, `docker-compose*.yml`, `kubernetes/`, `terraform/`
- **Jobs**: `dynamic-build-infrastructure`, `dynamic-deploy-infrastructure`

### Production Deployment
- **Triggers**: Main branch commits (`main`, `master`, `$CI_DEFAULT_BRANCH`)
- **Jobs**: `dynamic-deploy-production` (manual trigger)

## 📝 Logging System

The component includes standardized logging functions available in all jobs:

```bash
# Load logging functions
eval "$ECHO_FUNCTIONS"

# Use standardized logging
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

## 📁 Project Structure

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

## 🌍 Environment Variables

The following variables are available in child pipelines:

- `PARENT_PIPELINE_ID`: ID of the parent pipeline
- `CHILD_TYPE`: Set to `"dynamic"`
- `CHILD_PIPELINE_TYPE`: Set to `"dynamic"`
- `ECHO_FUNCTIONS`: Logging functions for standardized output

## 💡 Usage Examples

### Basic Project Integration

```yaml
include:
  - component: gitlab.example.com/components/child-pipeline-inheritance@v1.0.0

stages:
  - maintenance

custom-job:
  stage: maintenance
  script:
    - eval "$ECHO_FUNCTIONS"
    - log_info "Custom job running"
    - echo "Your logic here"
```

### Multi-Stage Project

```yaml
include:
  - component: gitlab.example.com/components/child-pipeline-inheritance@v1.0.0
    inputs:
      stage: "build"
      enable_validation: "true"

stages:
  - validate
  - build
  - test
  - deploy

test-integration:
  stage: test
  script:
    - eval "$ECHO_FUNCTIONS"
    - log_info "🧪 Running integration tests"
    - npm test
```

## 🔍 Troubleshooting

### Component Not Found
- Ensure the component project is published with semantic version releases
- Verify the component path and version reference
- Check if the component project is accessible from your project

### Missing Dependencies
- The component requires a GitLab Runner with `bash`, `git`, and `apt-get` support
- Ubuntu-based images are recommended (`ubuntu:latest` or `ubuntu:22.04`)

### Child Pipeline Not Generated
- Verify that component jobs are executing successfully
- Check the `generated-child-pipeline.yml` artifact is created
- Ensure your project has the required stages defined

## 📚 Version History

- **v1.0.0**: Initial component release
  - Dynamic pipeline generation
  - Standardized logging system
  - Multi-technology detection
  - Production deployment support

## 📄 License

This component is part of the GitLab CI/CD Labs collection and follows the same licensing terms.

## 🤝 Contributing

For issues, improvements, or questions:
1. Create an issue in this project
2. Submit a merge request with your changes
3. Follow the existing code style and patterns

## 🔗 Related Documentation

- [GitLab CI/CD Components Documentation](https://docs.gitlab.com/ee/ci/components/)
- [GitLab CI/CD Catalog](https://docs.gitlab.com/ee/ci/components/#cicd-catalog)
- [Child Pipelines Documentation](https://docs.gitlab.com/ee/ci/pipelines/parent_child_pipelines.html)