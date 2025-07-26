# Lab 7: Advanced Pipeline Patterns

## Objective
Learn advanced GitLab CI/CD patterns including child pipelines, matrix builds, include strategies, and complex workflow orchestration.

## Prerequisites
- Completed [Lab 6: Security Scanning](../lab-06-security-scanning/README.md)
- Solid understanding of basic pipeline concepts
- Experience with GitLab CI/CD variables and rules

## What You'll Learn
- Child and parent pipelines
- Matrix builds and parallel execution
- Pipeline includes and templates
- Dynamic pipeline generation
- Multi-project pipelines
- Conditional workflows
- Pipeline optimization strategies
- Advanced artifact management

## Advanced Pipeline Patterns

### 1. Child Pipelines
Break complex pipelines into manageable, reusable components:

```yaml
# Parent pipeline
generate_child_pipeline:
  stage: prepare
  script:
    - echo "Generating child pipeline configuration..."
    - |
      cat > child-pipeline.yml << EOF
      stages:
        - build
        - test
      
      build_microservice:
        stage: build
        script:
          - echo "Building microservice..."
      
      test_microservice:
        stage: test
        script:
          - echo "Testing microservice..."
      EOF
  artifacts:
    paths:
      - child-pipeline.yml

trigger_child_pipeline:
  stage: deploy
  trigger:
    include:
      - artifact: child-pipeline.yml
        job: generate_child_pipeline
    strategy: depend
```

### 2. Matrix Builds
Test across multiple environments and configurations:

```yaml
test_matrix:
  stage: test
  parallel:
    matrix:
      - NODE_VERSION: ["16", "18", "20"]
        OS: ["ubuntu-latest", "alpine"]
      - PYTHON_VERSION: ["3.8", "3.9", "3.10"]
        OS: ["ubuntu-latest"]
  image: $OS
  script:
    - echo "Testing on $OS with Node $NODE_VERSION Python $PYTHON_VERSION"
    - ./run-tests.sh
```

### 3. Dynamic Pipeline Includes
Conditionally include pipeline configurations:

```yaml
include:
  - local: '/pipelines/base.yml'
  - local: '/pipelines/security.yml'
    rules:
      - if: $SECURITY_SCAN_ENABLED == "true"
  - local: '/pipelines/performance.yml'
    rules:
      - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  - project: 'group/shared-templates'
    file: 'deployment.yml'
    ref: 'v2.0'
```

### 4. Multi-Project Pipelines
Orchestrate pipelines across multiple projects:

```yaml
trigger_downstream_projects:
  stage: deploy
  trigger:
    project: group/downstream-project
    branch: main
    strategy: depend
  variables:
    UPSTREAM_PROJECT: $CI_PROJECT_NAME
    UPSTREAM_COMMIT: $CI_COMMIT_SHA
```

## Lab Implementation

### Step 1: Dynamic Pipeline Generation

```yaml
# .gitlab-ci.yml - Main pipeline
stages:
  - prepare
  - generate
  - build
  - test
  - security
  - deploy

variables:
  # Feature flags
  ENABLE_MICROSERVICES: "true"
  ENABLE_FRONTEND: "true"
  ENABLE_MOBILE: "false"
  
  # Environment configuration
  TARGET_ENVIRONMENTS: "development,staging,production"
  
# Generate dynamic pipeline based on project structure
generate_pipeline:
  stage: prepare
  image: alpine:latest
  before_script:
    - apk add --no-cache jq yq
  script:
    - echo "=== Dynamic Pipeline Generation ==="
    - echo "Analyzing project structure..."
    
    # Detect project components
    - |
      COMPONENTS=""
      if [ -d "backend/" ]; then
        COMPONENTS="$COMPONENTS backend"
      fi
      if [ -d "frontend/" ]; then
        COMPONENTS="$COMPONENTS frontend"
      fi
      if [ -d "mobile/" ]; then
        COMPONENTS="$COMPONENTS mobile"
      fi
      if [ -d "docs/" ]; then
        COMPONENTS="$COMPONENTS docs"
      fi
    
    # Generate component-specific pipelines
    - echo "Detected components: $COMPONENTS"
    - |
      for component in $COMPONENTS; do
        echo "Generating pipeline for $component..."
        cat > ${component}-pipeline.yml << EOF
      stages:
        - build
        - test
        - package
      
      build_${component}:
        stage: build
        script:
          - echo "Building $component..."
          - cd $component/
          - ./build.sh
        artifacts:
          paths:
            - $component/dist/
          expire_in: 1 hour
      
      test_${component}:
        stage: test
        script:
          - echo "Testing $component..."
          - cd $component/
          - ./test.sh
        dependencies:
          - build_${component}
      
      package_${component}:
        stage: package
        script:
          - echo "Packaging $component..."
          - cd $component/
          - ./package.sh
        dependencies:
          - build_${component}
          - test_${component}
      EOF
      done
    
    # Generate main orchestration pipeline
    - |
      cat > orchestration-pipeline.yml << EOF
      stages:
        - orchestrate
        - validate
        - deploy
      
      orchestrate_builds:
        stage: orchestrate
        script:
          - echo "Orchestrating component builds..."
        parallel:
          matrix:
      EOF
    
    - |
      for component in $COMPONENTS; do
        echo "      - COMPONENT: [$component]" >> orchestration-pipeline.yml
      done
    
    - cat orchestration-pipeline.yml
  artifacts:
    paths:
      - "*-pipeline.yml"
    expire_in: 1 hour

# Trigger component pipelines
trigger_backend:
  stage: generate
  trigger:
    include:
      - artifact: backend-pipeline.yml
        job: generate_pipeline
    strategy: depend
  rules:
    - if: $ENABLE_MICROSERVICES == "true"
      exists:
        - backend/

trigger_frontend:
  stage: generate
  trigger:
    include:
      - artifact: frontend-pipeline.yml
        job: generate_pipeline
    strategy: depend
  rules:
    - if: $ENABLE_FRONTEND == "true"
      exists:
        - frontend/
```

### Step 2: Matrix Testing Strategy

```yaml
# Advanced matrix testing
cross_platform_testing:
  stage: test
  parallel:
    matrix:
      # Backend testing matrix
      - COMPONENT: "backend"
        RUNTIME: ["node:16", "node:18", "node:20"]
        DATABASE: ["postgres:13", "postgres:14", "mysql:8"]
      
      # Frontend testing matrix
      - COMPONENT: "frontend"
        BROWSER: ["chrome", "firefox", "safari"]
        VIEWPORT: ["desktop", "tablet", "mobile"]
      
      # Mobile testing matrix
      - COMPONENT: "mobile"
        PLATFORM: ["ios", "android"]
        VERSION: ["latest", "previous"]
  
  image: $RUNTIME
  services:
    - name: $DATABASE
      alias: database
  
  variables:
    TEST_DATABASE_URL: "$DATABASE_URL"
  
  script:
    - echo "Testing $COMPONENT on $RUNTIME with $DATABASE"
    - echo "Browser: $BROWSER, Viewport: $VIEWPORT"
    - echo "Platform: $PLATFORM, Version: $VERSION"
    - cd $COMPONENT/
    - ./run-tests.sh
  
  artifacts:
    when: always
    reports:
      junit: "$COMPONENT/test-results.xml"
    paths:
      - "$COMPONENT/coverage/"
    expire_in: 1 day
```

### Step 3: Conditional Workflow Orchestration

```yaml
# Workflow decision engine
workflow_decision:
  stage: prepare
  image: alpine:latest
  script:
    - echo "=== Workflow Decision Engine ==="
    
    # Analyze changes
    - |
      CHANGED_FILES=$(git diff --name-only $CI_COMMIT_BEFORE_SHA $CI_COMMIT_SHA || echo "")
      echo "Changed files: $CHANGED_FILES"
      
      # Determine workflow based on changes
      WORKFLOW_TYPE="minimal"
      
      if echo "$CHANGED_FILES" | grep -q "backend/"; then
        WORKFLOW_TYPE="backend"
      fi
      
      if echo "$CHANGED_FILES" | grep -q "frontend/"; then
        if [ "$WORKFLOW_TYPE" = "backend" ]; then
          WORKFLOW_TYPE="fullstack"
        else
          WORKFLOW_TYPE="frontend"
        fi
      fi
      
      if echo "$CHANGED_FILES" | grep -q "infrastructure/"; then
        WORKFLOW_TYPE="infrastructure"
      fi
      
      if [ "$CI_COMMIT_BRANCH" = "$CI_DEFAULT_BRANCH" ]; then
        WORKFLOW_TYPE="full"
      fi
      
      echo "Selected workflow: $WORKFLOW_TYPE"
      echo "WORKFLOW_TYPE=$WORKFLOW_TYPE" > workflow.env
  
  artifacts:
    reports:
      dotenv: workflow.env
    expire_in: 1 hour

# Conditional job execution based on workflow
backend_pipeline:
  stage: build
  trigger:
    include: 'pipelines/backend.yml'
    strategy: depend
  rules:
    - if: '$WORKFLOW_TYPE =~ /backend|fullstack|full/'

frontend_pipeline:
  stage: build
  trigger:
    include: 'pipelines/frontend.yml'
    strategy: depend
  rules:
    - if: '$WORKFLOW_TYPE =~ /frontend|fullstack|full/'

infrastructure_pipeline:
  stage: deploy
  trigger:
    include: 'pipelines/infrastructure.yml'
    strategy: depend
  rules:
    - if: '$WORKFLOW_TYPE =~ /infrastructure|full/'
```

### Step 4: Advanced Artifact Management

```yaml
# Artifact lifecycle management
artifact_manager:
  stage: prepare
  image: alpine:latest
  script:
    - echo "=== Artifact Lifecycle Management ==="
    
    # Create artifact metadata
    - |
      cat > artifact-metadata.json << EOF
      {
        "pipeline_id": "$CI_PIPELINE_ID",
        "commit_sha": "$CI_COMMIT_SHA",
        "branch": "$CI_COMMIT_REF_NAME",
        "timestamp": "$(date -Iseconds)",
        "artifacts": {
          "retention_policy": {
            "development": "7 days",
            "staging": "30 days",
            "production": "1 year"
          }
        }
      }
      EOF
    
  artifacts:
    paths:
      - artifact-metadata.json
    expire_in: 1 week

# Smart artifact passing
smart_artifact_pass:
  stage: build
  parallel:
    matrix:
      - SERVICE: ["api", "worker", "scheduler"]
        ENVIRONMENT: ["dev", "staging", "prod"]
  script:
    - echo "Building $SERVICE for $ENVIRONMENT"
    - mkdir -p artifacts/$SERVICE/$ENVIRONMENT
    - echo "$SERVICE build for $ENVIRONMENT" > artifacts/$SERVICE/$ENVIRONMENT/build.txt
  artifacts:
    name: "$SERVICE-$ENVIRONMENT-$CI_COMMIT_SHORT_SHA"
    paths:
      - artifacts/$SERVICE/$ENVIRONMENT/
    expire_in: 1 week
    when: on_success
```

### Step 5: Pipeline Optimization Patterns

```yaml
# Intelligent caching strategy
optimized_build:
  stage: build
  image: node:18
  cache:
    key:
      files:
        - package-lock.json
      prefix: $CI_COMMIT_REF_SLUG
    paths:
      - node_modules/
      - .npm/
    policy: pull-push
    when: always
  
  before_script:
    - echo "Optimized build with intelligent caching"
    - npm ci --cache .npm --prefer-offline
  
  script:
    - npm run build
  
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour
    when: always

# Parallel deployment strategy
parallel_deployment:
  stage: deploy
  parallel: 3
  script:
    - echo "Deploying to region $CI_NODE_INDEX"
    - case $CI_NODE_INDEX in
        1) REGION="us-east-1" ;;
        2) REGION="eu-west-1" ;;
        3) REGION="ap-southeast-1" ;;
      esac
    - echo "Deploying to $REGION"
    - ./deploy.sh $REGION
  
  environment:
    name: production-$CI_NODE_INDEX
    url: https://app-$CI_NODE_INDEX.example.com
```

## Advanced Include Patterns

### Template Hierarchy

```yaml
# .gitlab/ci/templates/base.yml
.base_job:
  before_script:
    - echo "Base job setup"
  after_script:
    - echo "Base job cleanup"
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure

.build_template:
  extends: .base_job
  stage: build
  artifacts:
    expire_in: 1 hour

.test_template:
  extends: .base_job
  stage: test
  artifacts:
    when: always
    reports:
      junit: test-results.xml
```

### Conditional Includes

```yaml
# Main .gitlab-ci.yml
include:
  # Always include base templates
  - local: '.gitlab/ci/templates/base.yml'
  
  # Conditional includes based on project structure
  - local: '.gitlab/ci/backend.yml'
    rules:
      - exists: ['backend/**/*']
  
  - local: '.gitlab/ci/frontend.yml'
    rules:
      - exists: ['frontend/**/*']
  
  # Environment-specific includes
  - local: '.gitlab/ci/production.yml'
    rules:
      - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  
  # External template includes
  - project: 'templates/security-scanning'
    file: 'security.yml'
    ref: 'v2.1'
    rules:
      - if: $SECURITY_ENABLED == "true"
```

## Best Practices

### 1. Pipeline Organization
- Keep pipelines modular and reusable
- Use meaningful stage and job names
- Implement proper error handling
- Document complex pipeline logic

### 2. Performance Optimization
- Use intelligent caching strategies
- Implement parallel execution where possible
- Optimize Docker image layers
- Minimize artifact sizes

### 3. Maintainability
- Use templates for common patterns
- Implement proper versioning
- Create clear documentation
- Regular pipeline reviews

### 4. Security Considerations
- Limit pipeline access permissions
- Use protected variables for secrets
- Implement approval workflows
- Regular security audits

## Expected Results

1. **Dynamic Pipelines**: Automatically adapt to project structure
2. **Matrix Testing**: Comprehensive cross-platform testing
3. **Workflow Orchestration**: Intelligent pipeline routing
4. **Optimized Performance**: Faster pipeline execution
5. **Maintainable Code**: Reusable and modular pipeline components

## Next Steps

Proceed to [Lab 8: GitLab Runner Management](../lab-08-runner-management/README.md) to learn about managing and optimizing GitLab Runners.

## Reference

- [GitLab CI/CD Pipelines](https://docs.gitlab.com/ee/ci/pipelines/)
- [Child Pipelines](https://docs.gitlab.com/ee/ci/pipelines/parent_child_pipelines.html)
- [Matrix Builds](https://docs.gitlab.com/ee/ci/yaml/#parallel)
- [Pipeline Includes](https://docs.gitlab.com/ee/ci/yaml/#include)