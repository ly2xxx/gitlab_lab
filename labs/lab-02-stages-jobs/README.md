# Lab 2: Stages and Jobs

## Objective
Learn how to organize your pipeline using stages and understand job execution order, dependencies, and parallelization.

## Prerequisites
- Completed [Lab 1: Basic Pipeline](../lab-01-basic-pipeline/README.md)
- Understanding of basic `.gitlab-ci.yml` syntax

## What You'll Learn
- Pipeline stages concept
- Job execution order and dependencies
- Parallel vs sequential execution
- Job naming conventions
- Stage-specific configurations

## Understanding Stages

Stages define the execution order of jobs:
1. Jobs in the same stage run **in parallel**
2. Jobs in the next stage run **after** all jobs in the previous stage complete
3. If any job in a stage fails, the next stage won't execute (by default)

## Lab Steps

### Step 1: Define Stages

Create a pipeline with explicit stages:

```yaml
# Define the stages in execution order
stages:
  - prepare
  - build
  - test
  - deploy

variables:
  APP_NAME: "GitLab CI/CD Tutorial App"

# Prepare stage jobs
setup_environment:
  stage: prepare
  script:
    - echo "Setting up build environment..."
    - echo "App: $APP_NAME"
    - echo "Creating directories..."
    - mkdir -p build artifacts logs
    - echo "Environment ready!"

check_dependencies:
  stage: prepare
  script:
    - echo "Checking system dependencies..."
    - echo "Git: $(git --version)"
    - echo "Available disk space:"
    - df -h 2>/dev/null || echo "df command not available"
    - echo "Dependencies check complete!"
```

### Step 2: Add Build Jobs

```yaml
# Build stage jobs (run after prepare stage)
compile_app:
  stage: build
  script:
    - echo "Compiling application..."
    - echo "Build started at: $(date)"
    - sleep 3  # Simulate build time
    - echo "Creating build artifacts..."
    - echo "Build complete!" > build/app.txt
    - echo "Build finished at: $(date)"
  artifacts:
    paths:
      - build/
    expire_in: 1 hour

build_documentation:
  stage: build
  script:
    - echo "Building documentation..."
    - echo "Generating docs..."
    - sleep 2  # Simulate doc generation
    - mkdir -p build/docs
    - echo "# App Documentation" > build/docs/README.md
    - echo "Documentation build complete!"
  artifacts:
    paths:
      - build/docs/
    expire_in: 1 hour
```

### Step 3: Add Test Jobs

```yaml
# Test stage jobs (run after build stage)
unit_tests:
  stage: test
  dependencies:
    - compile_app
  script:
    - echo "Running unit tests..."
    - echo "Testing build artifact..."
    - cat build/app.txt
    - echo "All unit tests passed!"

integration_tests:
  stage: test
  dependencies:
    - compile_app
  script:
    - echo "Running integration tests..."
    - echo "Testing application integration..."
    - sleep 4  # Simulate test execution
    - echo "Integration tests completed!"

code_quality:
  stage: test
  script:
    - echo "Running code quality checks..."
    - echo "Linting code..."
    - echo "Security scan..."
    - echo "Code quality checks passed!"
```

### Step 4: Add Deploy Job

```yaml
# Deploy stage (runs after all tests pass)
deploy_staging:
  stage: deploy
  dependencies:
    - compile_app
    - build_documentation
  script:
    - echo "Deploying to staging environment..."
    - echo "Deploying artifacts:"
    - ls -la build/
    - echo "Application deployed successfully!"
    - echo "Staging URL: https://staging.example.com"
  environment:
    name: staging
    url: https://staging.example.com
```

## Complete Example

See the complete `.gitlab-ci.yml` file in this lab directory.

## Understanding Job Dependencies

### Implicit Dependencies
- Jobs in later stages automatically depend on all jobs in previous stages

### Explicit Dependencies
- Use `dependencies:` to specify which jobs' artifacts you need
- Use `needs:` for more complex dependency graphs (advanced)

### Artifacts
- Files/directories passed between jobs
- Stored temporarily in GitLab
- Downloaded automatically for dependent jobs

## Pipeline Visualization

```
PREPARE STAGE:
┌─────────────────┐    ┌─────────────────┐
│ setup_environment│    │check_dependencies│  (parallel)
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
BUILD STAGE:
┌─────────────────┐    ┌─────────────────┐
│   compile_app   │    │build_documentation│  (parallel)
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     ▼
TEST STAGE:
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   unit_tests    │  │integration_tests│  │  code_quality   │  (parallel)
└─────────────────┘  └─────────────────┘  └─────────────────┘
                              │
                              ▼
DEPLOY STAGE:
                    ┌─────────────────┐
                    │ deploy_staging  │
                    └─────────────────┘
```

## Expected Results

1. **Prepare stage**: Both jobs run in parallel
2. **Build stage**: Starts after prepare completes, jobs run in parallel
3. **Test stage**: Starts after build completes, all tests run in parallel
4. **Deploy stage**: Runs only if all tests pass
5. **Artifacts**: Build artifacts are available in test and deploy stages

## Common Issues & Solutions

**Issue**: Jobs in same stage don't run in parallel
- **Solution**: Check if you have enough available runners

**Issue**: Next stage doesn't start
- **Solution**: Check if all jobs in previous stage completed successfully

**Issue**: Artifacts not found in dependent job
- **Solution**: Verify `dependencies:` list and artifact paths

**Issue**: Stage runs when it shouldn't
- **Solution**: Check job `rules:` or `only:`/`except:` conditions

## Best Practices

1. **Stage Naming**: Use descriptive names (prepare, build, test, deploy)
2. **Job Naming**: Use clear, descriptive job names
3. **Parallel Execution**: Keep jobs in same stage independent
4. **Artifact Management**: Only pass necessary files between stages
5. **Fail Fast**: Put quick checks in early stages

## Next Steps

Proceed to [Lab 3: Variables and Artifacts](../lab-03-variables-artifacts/README.md) to learn advanced variable usage and artifact management.

## Reference

- [GitLab CI/CD Stages Documentation](https://docs.gitlab.com/ee/ci/yaml/#stages)
- [Job Dependencies](https://docs.gitlab.com/ee/ci/yaml/#dependencies)
- [Artifacts](https://docs.gitlab.com/ee/ci/yaml/#artifacts)