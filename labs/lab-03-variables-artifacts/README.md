# Lab 3: Variables and Artifacts

## Objective
Master GitLab CI/CD variables, artifact management, and file passing between jobs to create more sophisticated pipelines.

## Prerequisites
- Completed [Lab 2: Stages and Jobs](../lab-02-stages-jobs/README.md)
- Understanding of pipeline stages and job dependencies

## What You'll Learn
- Different types of GitLab CI/CD variables
- Custom variable definition and usage
- Artifact creation, management, and consumption
- File and directory passing between jobs
- Environment-specific configurations
- Security considerations for variables

## Variable Types in GitLab CI/CD

### 1. Predefined Variables
GitLab provides many built-in variables:
- `$CI_PROJECT_NAME` - Project name
- `$CI_COMMIT_SHA` - Commit SHA
- `$CI_PIPELINE_ID` - Pipeline ID
- `$CI_JOB_NAME` - Current job name
- `$CI_COMMIT_REF_NAME` - Branch/tag name

### 2. Custom Variables
Defined in:
- `.gitlab-ci.yml` file (global or job-level)
- GitLab UI (Project/Group settings)
- GitLab CI/CD API

### 3. Variable Precedence
1. Job-level variables (highest)
2. Global variables in `.gitlab-ci.yml`
3. Group variables
4. Project variables
5. Predefined variables (lowest)

## Lab Steps

### Step 1: Working with Variables

Create a comprehensive variable example:

```yaml
# Global variables available to all jobs
variables:
  # Application configuration
  APP_NAME: "Variable Demo App"
  APP_VERSION: "1.2.3"
  BUILD_TARGET: "production"
  
  # Build configuration
  BUILD_DIR: "dist"
  ARTIFACT_DIR: "artifacts"
  LOG_LEVEL: "INFO"
  
  # Environment URLs
  STAGING_URL: "https://staging.example.com"
  PROD_URL: "https://production.example.com"

stages:
  - validate
  - build
  - package
  - deploy

# Job with custom variables
validate_config:
  stage: validate
  variables:
    # Job-specific variables
    VALIDATION_MODE: "strict"
    MAX_WARNINGS: "5"
  script:
    - echo "=== Configuration Validation ==="
    - echo "App: $APP_NAME v$APP_VERSION"
    - echo "Target: $BUILD_TARGET"
    - echo "Validation Mode: $VALIDATION_MODE"
    - echo "Max Warnings: $MAX_WARNINGS"
    - echo "Log Level: $LOG_LEVEL"
    - echo "GitLab Variables:"
    - echo "  Project: $CI_PROJECT_NAME"
    - echo "  Pipeline: $CI_PIPELINE_ID"
    - echo "  Commit: $CI_COMMIT_SHORT_SHA"
    - echo "  Branch: $CI_COMMIT_REF_NAME"
    - echo "✓ Configuration valid"
```

### Step 2: Creating and Managing Artifacts

```yaml
# Build job that creates multiple artifacts
build_application:
  stage: build
  variables:
    COMPILER_FLAGS: "-O2 -Wall"
  script:
    - echo "=== Building Application ==="
    - echo "Creating build directory: $BUILD_DIR"
    - mkdir -p $BUILD_DIR $ARTIFACT_DIR logs
    
    # Simulate building different components
    - echo "Building main application..."
    - echo "App: $APP_NAME" > $BUILD_DIR/app-info.txt
    - echo "Version: $APP_VERSION" >> $BUILD_DIR/app-info.txt
    - echo "Built: $(date)" >> $BUILD_DIR/app-info.txt
    - echo "Compiler Flags: $COMPILER_FLAGS" >> $BUILD_DIR/app-info.txt
    
    # Create a fake binary
    - echo "#!/bin/bash\necho 'Running $APP_NAME v$APP_VERSION'" > $BUILD_DIR/myapp
    - chmod +x $BUILD_DIR/myapp
    
    # Create configuration files
    - echo "log_level=$LOG_LEVEL" > $BUILD_DIR/config.properties
    - echo "app_name=$APP_NAME" >> $BUILD_DIR/config.properties
    - echo "version=$APP_VERSION" >> $BUILD_DIR/config.properties
    
    # Generate build logs
    - echo "Build started: $(date)" > logs/build.log
    - echo "Compiler: gcc" >> logs/build.log
    - echo "Flags: $COMPILER_FLAGS" >> logs/build.log
    - echo "Build completed: $(date)" >> logs/build.log
    
    - echo "Build completed successfully!"
    - ls -la $BUILD_DIR/
  artifacts:
    name: "$APP_NAME-$APP_VERSION-$CI_COMMIT_SHORT_SHA"
    paths:
      - $BUILD_DIR/
      - logs/
    exclude:
      - logs/*.tmp
    expire_in: 2 hours
    when: always
    reports:
      # For future use with test reports, coverage, etc.
```

### Step 3: Package and Documentation Artifacts

```yaml
generate_documentation:
  stage: build
  variables:
    DOC_FORMAT: "html"
    DOC_THEME: "default"
  script:
    - echo "=== Generating Documentation ==="
    - mkdir -p $ARTIFACT_DIR/docs
    
    # Create comprehensive documentation
    - echo "# $APP_NAME Documentation" > $ARTIFACT_DIR/docs/index.html
    - echo "<h1>$APP_NAME v$APP_VERSION</h1>" >> $ARTIFACT_DIR/docs/index.html
    - echo "<p>Generated on: $(date)</p>" >> $ARTIFACT_DIR/docs/index.html
    - echo "<p>Pipeline: $CI_PIPELINE_ID</p>" >> $ARTIFACT_DIR/docs/index.html
    - echo "<p>Commit: $CI_COMMIT_SHA</p>" >> $ARTIFACT_DIR/docs/index.html
    
    # API documentation
    - echo "# API Documentation" > $ARTIFACT_DIR/docs/api.md
    - echo "Version: $APP_VERSION" >> $ARTIFACT_DIR/docs/api.md
    - echo "Base URL: $STAGING_URL/api/v1" >> $ARTIFACT_DIR/docs/api.md
    
    # User manual
    - echo "# User Manual" > $ARTIFACT_DIR/docs/manual.md
    - echo "Application: $APP_NAME" >> $ARTIFACT_DIR/docs/manual.md
    - echo "Version: $APP_VERSION" >> $ARTIFACT_DIR/docs/manual.md
    
    - echo "Documentation generated in format: $DOC_FORMAT"
    - echo "Theme: $DOC_THEME"
    - ls -la $ARTIFACT_DIR/docs/
  artifacts:
    name: "docs-$CI_COMMIT_SHORT_SHA"
    paths:
      - $ARTIFACT_DIR/docs/
    expire_in: 1 week

create_package:
  stage: package
  dependencies:
    - build_application
    - generate_documentation
  variables:
    PACKAGE_FORMAT: "tar.gz"
    PACKAGE_NAME: "$APP_NAME-$APP_VERSION"
  script:
    - echo "=== Creating Deployment Package ==="
    - echo "Package format: $PACKAGE_FORMAT"
    - echo "Package name: $PACKAGE_NAME"
    
    # Verify artifacts are available
    - echo "Available build artifacts:"
    - ls -la $BUILD_DIR/ || echo "Build artifacts not found!"
    - echo "Available documentation:"
    - ls -la $ARTIFACT_DIR/docs/ || echo "Documentation not found!"
    
    # Create package structure
    - mkdir -p package/$PACKAGE_NAME
    - cp -r $BUILD_DIR/* package/$PACKAGE_NAME/ 2>/dev/null || echo "No build files to copy"
    - cp -r $ARTIFACT_DIR/docs package/$PACKAGE_NAME/ 2>/dev/null || echo "No docs to copy"
    
    # Create package metadata
    - echo "Package: $PACKAGE_NAME" > package/$PACKAGE_NAME/PACKAGE_INFO
    - echo "Version: $APP_VERSION" >> package/$PACKAGE_NAME/PACKAGE_INFO
    - echo "Created: $(date)" >> package/$PACKAGE_NAME/PACKAGE_INFO
    - echo "Pipeline: $CI_PIPELINE_ID" >> package/$PACKAGE_NAME/PACKAGE_INFO
    - echo "Commit: $CI_COMMIT_SHA" >> package/$PACKAGE_NAME/PACKAGE_INFO
    
    # Create the package
    - cd package
    - tar -czf $PACKAGE_NAME.tar.gz $PACKAGE_NAME/
    - cd ..
    - mv package/$PACKAGE_NAME.tar.gz $ARTIFACT_DIR/
    
    - echo "Package created successfully!"
    - ls -la $ARTIFACT_DIR/
  artifacts:
    name: "package-$APP_NAME-$APP_VERSION"
    paths:
      - $ARTIFACT_DIR/$PACKAGE_NAME.tar.gz
      - package/$PACKAGE_NAME/PACKAGE_INFO
    expire_in: 1 month
```

### Step 4: Environment-Specific Deployments

```yaml
deploy_staging:
  stage: deploy
  dependencies:
    - create_package
  variables:
    DEPLOY_ENV: "staging"
    DEPLOY_URL: "$STAGING_URL"
    DB_HOST: "staging-db.internal"
    REPLICAS: "2"
  script:
    - echo "=== Deploying to Staging ==="
    - echo "Environment: $DEPLOY_ENV"
    - echo "URL: $DEPLOY_URL"
    - echo "Database: $DB_HOST"
    - echo "Replicas: $REPLICAS"
    
    # Verify package
    - ls -la $ARTIFACT_DIR/
    - echo "Extracting package..."
    - cd $ARTIFACT_DIR
    - tar -tzf $APP_NAME-$APP_VERSION.tar.gz | head -10
    
    # Simulate deployment
    - echo "Deploying $APP_NAME v$APP_VERSION to $DEPLOY_ENV..."
    - sleep 3
    - echo "✓ Deployment completed successfully!"
    
    # Create deployment report
    - echo "Deployment Report" > deployment-$DEPLOY_ENV.txt
    - echo "App: $APP_NAME" >> deployment-$DEPLOY_ENV.txt
    - echo "Version: $APP_VERSION" >> deployment-$DEPLOY_ENV.txt
    - echo "Environment: $DEPLOY_ENV" >> deployment-$DEPLOY_ENV.txt
    - echo "URL: $DEPLOY_URL" >> deployment-$DEPLOY_ENV.txt
    - echo "Deployed: $(date)" >> deployment-$DEPLOY_ENV.txt
    - echo "Pipeline: $CI_PIPELINE_ID" >> deployment-$DEPLOY_ENV.txt
  environment:
    name: staging
    url: $STAGING_URL
  artifacts:
    name: "deployment-staging"
    paths:
      - $ARTIFACT_DIR/deployment-staging.txt
    expire_in: 3 days

deploy_production:
  stage: deploy
  dependencies:
    - create_package
  variables:
    DEPLOY_ENV: "production"
    DEPLOY_URL: "$PROD_URL"
    DB_HOST: "prod-db.internal"
    REPLICAS: "5"
  script:
    - echo "=== Deploying to Production ==="
    - echo "🚀 PRODUCTION DEPLOYMENT"
    - echo "Environment: $DEPLOY_ENV"
    - echo "URL: $DEPLOY_URL"
    - echo "Database: $DB_HOST"
    - echo "Replicas: $REPLICAS"
    
    # Extra validation for production
    - echo "Running pre-deployment checks..."
    - sleep 2
    - echo "✓ Pre-deployment checks passed"
    
    # Deploy
    - echo "Deploying $APP_NAME v$APP_VERSION to $DEPLOY_ENV..."
    - sleep 5
    - echo "✓ Production deployment completed!"
    
    # Post-deployment verification
    - echo "Running post-deployment verification..."
    - sleep 2
    - echo "✓ Post-deployment verification passed"
  environment:
    name: production
    url: $PROD_URL
  when: manual
  only:
    - main
```

## Advanced Variable Techniques

### Dynamic Variables
```yaml
variables:
  DYNAMIC_VERSION: "${APP_VERSION}-${CI_COMMIT_SHORT_SHA}"
  BUILD_TAG: "build-${CI_PIPELINE_ID}"
```

### Conditional Variables
```yaml
variables:
  DEPLOY_STRATEGY: $([[ "$CI_COMMIT_REF_NAME" == "main" ]] && echo "blue-green" || echo "rolling")
```

## Best Practices

### Variable Management
1. **Naming**: Use UPPER_CASE with underscores
2. **Grouping**: Organize related variables together
3. **Documentation**: Comment complex variable usage
4. **Defaults**: Provide sensible default values

### Artifact Management
1. **Naming**: Use descriptive, versioned names
2. **Size**: Keep artifacts as small as possible
3. **Expiration**: Set appropriate expiration times
4. **Dependencies**: Only depend on necessary artifacts

### Security
1. **Sensitive Data**: Use protected variables for secrets
2. **Masking**: Enable variable masking for sensitive values
3. **Scope**: Limit variable scope to necessary jobs

## Common Issues & Solutions

**Issue**: Variable not expanding
- **Solution**: Check variable name spelling and scope

**Issue**: Artifact not found in dependent job
- **Solution**: Verify `dependencies:` list and artifact paths

**Issue**: Large artifacts causing slow pipelines
- **Solution**: Exclude unnecessary files, compress artifacts

**Issue**: Variables overriding each other
- **Solution**: Review variable precedence rules

## Expected Results

1. **Variables**: All variables expand correctly in different scopes
2. **Artifacts**: Files are properly created and passed between jobs
3. **Packages**: Complete deployment packages are created
4. **Environments**: Different configurations for each environment

## Next Steps

Proceed to [Lab 4: Docker Integration](../lab-04-docker-integration/README.md) to learn about containerizing your applications and using Docker in GitLab CI/CD.

## Reference

- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)
- [Predefined Variables](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html)
- [Artifacts](https://docs.gitlab.com/ee/ci/yaml/#artifacts)