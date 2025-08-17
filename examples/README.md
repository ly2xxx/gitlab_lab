# Usage Examples for Child Pipeline Inheritance Component

This directory contains practical examples showing different ways to use the Child Pipeline Inheritance Component in your GitLab CI/CD pipelines.

## 📁 Example Files

### [`basic-usage.yml`](./basic-usage.yml)
**Use Case**: Simple project with minimal configuration  
**Features**:
- Default component settings
- Basic stage configuration
- Custom deployment job with component logging
- Manual production deployment

**Best For**:
- Small projects
- Getting started with the component
- Learning component basics

### [`advanced-usage.yml`](./advanced-usage.yml)
**Use Case**: Full-featured application with comprehensive testing  
**Features**:
- Complete input customization
- Multi-stage pipeline (validate, build, test, security, deploy)
- Integration and E2E testing
- Security scanning integration
- Multi-environment deployments
- Code coverage reporting

**Best For**:
- Production applications
- Teams requiring comprehensive CI/CD
- Projects with strict quality gates

### [`multi-project-usage.yml`](./multi-project-usage.yml)
**Use Case**: Microservices orchestration across multiple projects  
**Features**:
- Cross-project pipeline triggering
- Multi-service coordination
- Environment health checking
- Integration testing across services
- Deployment orchestration

**Best For**:
- Microservices architectures
- Complex multi-project setups
- Enterprise deployment orchestration

## 🚀 How to Use These Examples

### 1. Choose Your Example
Select the example that best matches your project needs:
- **Starting out?** Use `basic-usage.yml`
- **Need full CI/CD?** Use `advanced-usage.yml`
- **Managing microservices?** Use `multi-project-usage.yml`

### 2. Copy and Customize
```bash
# Copy the example to your project
cp examples/basic-usage.yml my-project/.gitlab-ci.yml

# Edit the component reference
# Replace: $CI_SERVER_FQDN/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME
# With your actual component location
```

### 3. Update Component Reference
Make sure to update the component reference to point to your component:

```yaml
include:
  - component: gitlab.example.com/your-group/your-component-project/child-pipeline-inheritance@v1.0.0
    # OR for local GitLab instances:
  - component: your-gitlab.com/components/child-pipeline-inheritance@v1.0.0
```

### 4. Customize Variables
Update the variables to match your project:

```yaml
variables:
  PROJECT_NAME: "your-project-name"
  BUILD_VERSION: "your-version"
  DOCKER_REGISTRY: "$CI_REGISTRY"
```

### 5. Adjust Stages
Ensure your stages include the stage specified in component inputs:

```yaml
# If using inputs.stage: "build"
stages:
  - validate
  - build    # Component jobs run here
  - test
  - deploy
```

## 💡 Component Features Demonstrated

### Standardized Logging
All examples show how to use the component's Java-style logging:

```yaml
script:
  - eval "$ECHO_FUNCTIONS"
  - log_info "Starting process"
  - log_debug "Debug information"
  - log_warn "Warning message"
  - log_error "Error occurred"
```

### Dynamic Child Pipelines
The component automatically generates child pipelines based on your repository structure:

- **Frontend detection**: `frontend/`, `*.js`, `*.html`, `package.json`
- **Backend detection**: `backend/`, `*.py`, `*.java`, `requirements.txt`
- **Infrastructure detection**: `Dockerfile`, `docker-compose.yml`, `kubernetes/`

### Variable Inheritance
Child pipelines automatically inherit:
- All parent pipeline variables
- CI/CD predefined variables
- Custom variables passed through component

### Production Deployment
Automatic production deployment detection for main branches with manual approval gates.

## 🔧 Customization Tips

### Input Parameters
Customize component behavior through inputs:

```yaml
include:
  - component: your-component-reference
    inputs:
      stage: "build"                    # Stage for component jobs
      enable_backend_build: "true"      # Enable/disable backend builds
      enable_validation: "true"         # Enable/disable validation
      docker_image: "ubuntu:22.04"      # Container image to use
```

### Stage Configuration
Choose the right stage strategy:

```yaml
# Option 1: Dedicated component stage
stages:
  - maintenance  # Component runs here

# Option 2: Integrated with existing stages  
stages:
  - validate
  - build      # Component runs here
  - test
  - deploy
```

### Environment-Specific Configuration
Use GitLab variables for environment-specific settings:

```yaml
variables:
  # Use predefined variables
  ENVIRONMENT: $CI_COMMIT_REF_NAME
  
  # Environment-specific URLs
  API_URL: "https://api-${CI_COMMIT_REF_NAME}.example.com"
  
  # Conditional variables
  SECURITY_SCAN: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH ? "true" : "false"
```

## 🐛 Troubleshooting

### Component Not Found
Ensure the component is published and accessible:
- Check component project has proper releases
- Verify component path is correct
- Confirm your project has access to the component project

### Missing Variables
If component logging functions aren't available:
- Ensure you're using `eval "$ECHO_FUNCTIONS"` 
- Check that component is properly included
- Verify no variable name conflicts

### Child Pipeline Not Generated
If child pipelines aren't created:
- Check component jobs are running successfully
- Verify artifact generation in `component-generate-child-pipeline`
- Ensure trigger job has proper dependencies

## 📚 Additional Resources

- [Component Documentation](../COMPONENT-README.md)
- [GitLab CI/CD Components](https://docs.gitlab.com/ee/ci/components/)
- [Child Pipelines](https://docs.gitlab.com/ee/ci/pipelines/parent_child_pipelines.html)
- [Pipeline Variables](https://docs.gitlab.com/ee/ci/variables/)

## 🤝 Contributing Examples

Have a useful example configuration? Contribute it!

1. Create a new example file following the naming pattern
2. Add comprehensive comments explaining the use case
3. Update this README with the new example
4. Submit a merge request with your addition

Examples we'd love to see:
- Monorepo with multiple services
- Gaming/mobile app deployment
- ML/Data pipeline integration
- Enterprise compliance workflows