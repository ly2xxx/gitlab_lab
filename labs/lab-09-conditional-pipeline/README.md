# Lab 9: Conditional Pipeline Execution

## Objective
Master conditional pipeline execution to optimize CI/CD performance by running only relevant tests when specific components change, reducing execution time and resource usage for multi-language projects.

## Prerequisites
- Completed Lab 7: Advanced Patterns
- Understanding of GitLab CI/CD rules and variables
- Multi-language project structure knowledge
- Git change detection concepts

## What You'll Learn
- Conditional execution using `rules:changes`
- Multi-language pipeline optimization
- Dynamic pipeline generation
- Child pipeline triggers
- Performance optimization strategies
- Language-specific template management

## Problem Statement
In large multi-language projects, testing all pipeline templates when only one language component changes is inefficient. This lab teaches you to implement smart conditional execution that only runs relevant tests based on file changes.

## Lab Structure Overview

```
project/
├── templates/
│   ├── python/
│   │   ├── django.yml
│   │   ├── flask.yml
│   │   └── common.yml
│   ├── nodejs/
│   │   ├── react.yml
│   │   ├── express.yml
│   │   └── common.yml
│   └── java/
│       ├── spring-boot.yml
│       ├── maven.yml
│       └── common.yml
├── shared/
│   ├── common/
│   ├── python/
│   ├── nodejs/
│   └── java/
├── scripts/
│   ├── test-python-pipelines.sh
│   ├── test-nodejs-pipelines.sh
│   ├── test-java-pipelines.sh
│   └── common/
└── tests/
    ├── python/
    ├── nodejs/
    └── java/
```

---

## Step 1: Basic Conditional Execution

### 1.1 Simple Rules with Changes

Create your first conditional pipeline that only runs when specific files change:

```yaml
# Basic conditional execution
stages:
  - validate
  - test

variables:
  GIT_DEPTH: 50  # Ensure enough history for change detection

# Python pipeline tests
test-python-templates:
  stage: test
  image: python:3.9
  script:
    - echo "Testing Python pipeline templates"
    - ./scripts/test-python-pipelines.sh
  rules:
    - changes:
        - "templates/python/**/*"
        - "shared/python/**/*"
        - "scripts/test-python-pipelines.sh"

# Node.js pipeline tests  
test-nodejs-templates:
  stage: test
  image: node:16
  script:
    - echo "Testing Node.js pipeline templates"
    - ./scripts/test-nodejs-pipelines.sh
  rules:
    - changes:
        - "templates/nodejs/**/*"
        - "shared/nodejs/**/*"
        - "scripts/test-nodejs-pipelines.sh"

# Java pipeline tests
test-java-templates:
  stage: test
  image: openjdk:11
  script:
    - echo "Testing Java pipeline templates"
    - ./scripts/test-java-pipelines.sh
  rules:
    - changes:
        - "templates/java/**/*"
        - "shared/java/**/*"
        - "scripts/test-java-pipelines.sh"
```

### 1.2 Testing the Basic Setup

1. Create a test file in `templates/python/test.yml`
2. Commit and push - only Python tests should run
3. Create a test file in `templates/nodejs/test.yml`
4. Commit and push - only Node.js tests should run

---

## Step 2: Advanced Conditional Patterns

### 2.1 Complex Rules with Multiple Conditions

```yaml
# Advanced conditional execution with multiple conditions
test-python-advanced:
  stage: test
  image: python:3.9
  script:
    - ./scripts/test-python-pipelines.sh
  rules:
    # Run on Python changes
    - changes:
        - "templates/python/**/*"
        - "shared/python/**/*"
      when: always
    # Run on merge requests affecting Python
    - if: $CI_MERGE_REQUEST_ID && $CI_MERGE_REQUEST_TARGET_BRANCH_NAME == "main"
      changes:
        - "templates/python/**/*"
      when: always
    # Manual trigger option
    - if: $CI_PIPELINE_SOURCE == "web"
      when: manual
      allow_failure: true

test-nodejs-with-conditions:
  stage: test
  image: node:16
  script:
    - ./scripts/test-nodejs-pipelines.sh
  rules:
    # Only run on feature branches for Node.js changes
    - if: $CI_COMMIT_BRANCH != "main"
      changes:
        - "templates/nodejs/**/*"
        - "shared/nodejs/**/*"
      when: always
    # Always run on main branch if Node.js files changed
    - if: $CI_COMMIT_BRANCH == "main"
      changes:
        - "templates/nodejs/**/*"
      when: always
```

### 2.2 Shared Dependencies Handler

```yaml
# Handle shared components that affect all languages
test-all-on-shared-changes:
  stage: test
  script:
    - echo "Running all tests due to shared component changes"
    - ./scripts/test-all-pipelines.sh
  rules:
    - changes:
        - ".gitlab-ci.yml"
        - "shared/common/**/*"
        - "scripts/common/**/*"
  parallel:
    matrix:
      - LANGUAGE: [python, nodejs, java]
  script:
    - echo "Testing $LANGUAGE pipelines"
    - ./scripts/test-${LANGUAGE}-pipelines.sh
```

---

## Step 3: Dynamic Pipeline Generation

### 3.1 Change Detection Script

Create a dynamic approach that detects changes and sets variables:

```yaml
# Dynamic pipeline generation
stages:
  - detect-changes
  - test-conditional

detect-changes:
  stage: detect-changes
  image: alpine/git
  script:
    - |
      echo "Detecting changes between $CI_MERGE_REQUEST_TARGET_BRANCH_SHA and HEAD"
      
      # Function to check if directory has changes
      check_changes() {
        local dir=$1
        local var_name=$2
        if git diff --name-only $CI_MERGE_REQUEST_TARGET_BRANCH_SHA..HEAD | grep -q "$dir"; then
          echo "${var_name}=true" >> build.env
          echo "$var_name detected changes"
        else
          echo "${var_name}=false" >> build.env
          echo "No changes in $var_name"
        fi
      }
      
      # Check each language component
      check_changes "templates/python\|shared/python" "PYTHON_CHANGED"
      check_changes "templates/nodejs\|shared/nodejs" "NODEJS_CHANGED"
      check_changes "templates/java\|shared/java" "JAVA_CHANGED"
      check_changes "shared/common" "SHARED_CHANGED"
      
      # Display detected changes
      echo "=== Change Detection Results ==="
      cat build.env
  artifacts:
    reports:
      dotenv: build.env
    expire_in: 1 hour
  rules:
    - if: $CI_MERGE_REQUEST_ID

# Conditional jobs based on detected changes
test-python-dynamic:
  stage: test-conditional
  image: python:3.9
  script:
    - echo "Running Python tests (dynamically triggered)"
    - ./scripts/test-python-pipelines.sh
  rules:
    - if: $PYTHON_CHANGED == "true" || $SHARED_CHANGED == "true"

test-nodejs-dynamic:
  stage: test-conditional
  image: node:16
  script:
    - echo "Running Node.js tests (dynamically triggered)"
    - ./scripts/test-nodejs-pipelines.sh
  rules:
    - if: $NODEJS_CHANGED == "true" || $SHARED_CHANGED == "true"

test-java-dynamic:
  stage: test-conditional
  image: openjdk:11
  script:
    - echo "Running Java tests (dynamically triggered)"
    - ./scripts/test-java-pipelines.sh
  rules:
    - if: $JAVA_CHANGED == "true" || $SHARED_CHANGED == "true"
```

---

## Step 4: Child Pipeline Strategy

### 4.1 Main Pipeline with Child Triggers

```yaml
# Main pipeline that triggers child pipelines conditionally
stages:
  - trigger-children

# Python child pipeline
trigger-python-pipeline:
  stage: trigger-children
  trigger:
    include: 
      - local: 'ci/python-pipeline.yml'
    strategy: depend
  rules:
    - changes:
        - "templates/python/**/*"
        - "shared/python/**/*"

# Node.js child pipeline
trigger-nodejs-pipeline:
  stage: trigger-children
  trigger:
    include: 
      - local: 'ci/nodejs-pipeline.yml'
    strategy: depend
  rules:
    - changes:
        - "templates/nodejs/**/*"
        - "shared/nodejs/**/*"

# Java child pipeline
trigger-java-pipeline:
  stage: trigger-children
  trigger:
    include: 
      - local: 'ci/java-pipeline.yml'
    strategy: depend
  rules:
    - changes:
        - "templates/java/**/*"
        - "shared/java/**/*"

# Comprehensive test on shared changes
trigger-all-pipelines:
  stage: trigger-children
  trigger:
    include:
      - local: 'ci/python-pipeline.yml'
      - local: 'ci/nodejs-pipeline.yml'
      - local: 'ci/java-pipeline.yml'
    strategy: depend
  rules:
    - changes:
        - "shared/common/**/*"
        - ".gitlab-ci.yml"
```

### 4.2 Child Pipeline Example (Python)

Create `ci/python-pipeline.yml`:

```yaml
# Child pipeline for Python testing
stages:
  - validate
  - test
  - integration

variables:
  PYTHON_VERSION: "3.9"

validate-python-syntax:
  stage: validate
  image: python:$PYTHON_VERSION
  script:
    - echo "Validating Python template syntax"
    - python -m py_compile templates/python/*.py || true
    - pip install pyyaml
    - python scripts/validate-yaml.py templates/python/

test-django-template:
  stage: test
  image: python:$PYTHON_VERSION
  script:
    - echo "Testing Django template"
    - ./scripts/test-django-template.sh
  rules:
    - changes:
        - "templates/python/django.yml"
        - "shared/python/django/**/*"

test-flask-template:
  stage: test
  image: python:$PYTHON_VERSION
  script:
    - echo "Testing Flask template"
    - ./scripts/test-flask-template.sh
  rules:
    - changes:
        - "templates/python/flask.yml"
        - "shared/python/flask/**/*"

integration-test-python:
  stage: integration
  image: python:$PYTHON_VERSION
  script:
    - echo "Running Python integration tests"
    - ./scripts/python-integration-tests.sh
  needs:
    - validate-python-syntax
```

---

## Step 5: Performance Optimization Techniques

### 5.1 Caching for Validation Results

```yaml
# Optimized pipeline with caching
.cache-template: &cache-template
  cache:
    key: "pipeline-validation-$CI_COMMIT_REF_SLUG-$CI_COMMIT_SHA"
    paths:
      - .validation-cache/
      - node_modules/
      - .venv/
    policy: pull-push

.validation-base:
  before_script:
    - mkdir -p .validation-cache
    - echo "Cache status:"
    - ls -la .validation-cache/ || echo "No cache found"

test-python-optimized:
  extends: .validation-base
  <<: *cache-template
  stage: test
  image: python:3.9
  script:
    - |
      CACHE_KEY="python-$(sha256sum templates/python/* | sha256sum | cut -d' ' -f1)"
      if [ -f ".validation-cache/$CACHE_KEY" ]; then
        echo "Python templates validation cached, skipping..."
        exit 0
      fi
      echo "Running Python template validation..."
      ./scripts/test-python-pipelines.sh
      touch ".validation-cache/$CACHE_KEY"
  rules:
    - changes:
        - "templates/python/**/*"
        - "shared/python/**/*"
```

### 5.2 Parallel Matrix Testing

```yaml
# Parallel testing with matrix strategy
test-templates-matrix:
  stage: test
  image: alpine:latest
  parallel:
    matrix:
      - LANGUAGE: [python, nodejs, java]
        TEMPLATE_TYPE: [basic, advanced, integration]
  script:
    - echo "Testing $LANGUAGE $TEMPLATE_TYPE templates"
    - apk add --no-cache bash
    - ./scripts/test-template.sh $LANGUAGE $TEMPLATE_TYPE
  rules:
    - changes:
        - "templates/$LANGUAGE/**/*"
        - "shared/$LANGUAGE/**/*"
```

---

## Step 6: Real-World Implementation

### 6.1 Complete Multi-Language Pipeline

This example shows a production-ready conditional pipeline:

```yaml
# Production-ready conditional pipeline
include:
  - local: 'ci/variables.yml'
  - local: 'ci/templates.yml'

stages:
  - detect
  - validate
  - test
  - integration
  - report

# Change detection job
.detect-changes: &detect-changes
  stage: detect
  image: alpine/git
  before_script:
    - apk add --no-cache bash jq
  script:
    - ./scripts/detect-changes.sh
  artifacts:
    reports:
      dotenv: changes.env
    expire_in: 1 hour

detect-python-changes:
  <<: *detect-changes
  script:
    - ./scripts/detect-changes.sh python
  rules:
    - changes:
        - "templates/python/**/*"
        - "shared/python/**/*"

detect-nodejs-changes:
  <<: *detect-changes
  script:
    - ./scripts/detect-changes.sh nodejs
  rules:
    - changes:
        - "templates/nodejs/**/*"
        - "shared/nodejs/**/*"

detect-java-changes:
  <<: *detect-changes
  script:
    - ./scripts/detect-changes.sh java
  rules:
    - changes:
        - "templates/java/**/*"
        - "shared/java/**/*"

# Language-specific testing jobs
.test-language-template: &test-language
  stage: test
  script:
    - ./scripts/test-language-templates.sh $LANGUAGE
  artifacts:
    reports:
      junit: "test-results/$LANGUAGE/junit.xml"
      coverage: "test-results/$LANGUAGE/coverage.xml"
    paths:
      - "test-results/$LANGUAGE/"
    expire_in: 1 week

test-python:
  <<: *test-language
  image: python:3.9
  variables:
    LANGUAGE: python
  rules:
    - changes:
        - "templates/python/**/*"
        - "shared/python/**/*"

test-nodejs:
  <<: *test-language
  image: node:16
  variables:
    LANGUAGE: nodejs
  rules:
    - changes:
        - "templates/nodejs/**/*"
        - "shared/nodejs/**/*"

test-java:
  <<: *test-language
  image: openjdk:11
  variables:
    LANGUAGE: java
  rules:
    - changes:
        - "templates/java/**/*"
        - "shared/java/**/*"

# Integration testing
integration-test:
  stage: integration
  image: alpine:latest
  script:
    - ./scripts/integration-test.sh
  rules:
    - changes:
        - "templates/**/*"
        - "shared/**/*"
  needs:
    - job: test-python
      optional: true
    - job: test-nodejs
      optional: true  
    - job: test-java
      optional: true

# Reporting
generate-report:
  stage: report
  image: alpine:latest
  script:
    - ./scripts/generate-report.sh
  artifacts:
    reports:
      dotenv: report.env
    paths:
      - reports/
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_MERGE_REQUEST_ID
```

---

## Step 7: Testing Scripts

### 7.1 Python Testing Script

Create `scripts/test-python-pipelines.sh`:

```bash
#!/bin/bash
set -e

echo "=== Testing Python Pipeline Templates ==="

# Install dependencies
pip install --quiet pyyaml yamllint

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    echo "Validating $file"
    yamllint -c .yamllint "$file"
    python -c "import yaml; yaml.safe_load(open('$file'))"
}

# Function to test pipeline template
test_template() {
    local template=$1
    echo "Testing template: $template"
    
    # Validate YAML syntax
    validate_yaml "$template"
    
    # Test template structure
    python scripts/validate-gitlab-ci.py "$template"
    
    # Run specific template tests
    case "$template" in
        *django*)
            echo "Running Django-specific tests"
            ./scripts/test-django-template.sh "$template"
            ;;
        *flask*)
            echo "Running Flask-specific tests"
            ./scripts/test-flask-template.sh "$template"
            ;;
        *)
            echo "Running generic Python template tests"
            ./scripts/test-generic-python.sh "$template"
            ;;
    esac
}

# Test all Python templates
echo "Found Python templates:"
find templates/python -name "*.yml" -type f

for template in templates/python/*.yml; do
    if [ -f "$template" ]; then
        test_template "$template"
    fi
done

echo "=== Python Pipeline Testing Complete ==="
```

### 7.2 Change Detection Script

Create `scripts/detect-changes.sh`:

```bash
#!/bin/bash
set -e

LANGUAGE=${1:-"all"}
BASE_BRANCH=${CI_MERGE_REQUEST_TARGET_BRANCH_SHA:-"origin/main"}
CURRENT_COMMIT=${CI_COMMIT_SHA:-"HEAD"}

echo "=== Detecting Changes for $LANGUAGE ==="
echo "Comparing $BASE_BRANCH to $CURRENT_COMMIT"

# Function to check changes in directory
check_directory_changes() {
    local dir_pattern=$1
    local env_var=$2
    
    if git diff --name-only "$BASE_BRANCH".."$CURRENT_COMMIT" | grep -q "$dir_pattern"; then
        echo "$env_var=true" >> changes.env
        echo "✓ Changes detected in $dir_pattern"
        
        # List changed files
        echo "Changed files:"
        git diff --name-only "$BASE_BRANCH".."$CURRENT_COMMIT" | grep "$dir_pattern" | sed 's/^/  - /'
        
        return 0
    else
        echo "$env_var=false" >> changes.env
        echo "✗ No changes in $dir_pattern"
        return 1
    fi
}

# Create changes.env file
echo "# Change detection results" > changes.env
echo "DETECTION_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> changes.env

case "$LANGUAGE" in
    "python")
        check_directory_changes "templates/python\|shared/python" "PYTHON_CHANGED"
        ;;
    "nodejs")
        check_directory_changes "templates/nodejs\|shared/nodejs" "NODEJS_CHANGED"
        ;;
    "java") 
        check_directory_changes "templates/java\|shared/java" "JAVA_CHANGED"
        ;;
    "all")
        check_directory_changes "templates/python\|shared/python" "PYTHON_CHANGED"
        check_directory_changes "templates/nodejs\|shared/nodejs" "NODEJS_CHANGED"
        check_directory_changes "templates/java\|shared/java" "JAVA_CHANGED"
        check_directory_changes "shared/common" "SHARED_CHANGED"
        check_directory_changes "\.gitlab-ci\.yml" "CI_CONFIG_CHANGED"
        ;;
    *)
        echo "Unknown language: $LANGUAGE"
        exit 1
        ;;
esac

echo ""
echo "=== Final Change Detection Results ==="
cat changes.env
```

---

## Testing the Lab

### Test Scenarios

1. **Single Language Change**:
   ```bash
   # Test Python-only changes
   touch templates/python/new-feature.yml
   git add . && git commit -m "Add Python template"
   git push
   # Only Python tests should run
   ```

2. **Multi-Language Change**:
   ```bash
   # Test multiple language changes
   touch templates/python/test.yml templates/nodejs/test.yml
   git add . && git commit -m "Update multiple languages"
   git push
   # Both Python and Node.js tests should run
   ```

3. **Shared Component Change**:
   ```bash
   # Test shared component changes
   touch shared/common/utils.sh
   git add . && git commit -m "Update shared utilities"
   git push
   # All language tests should run
   ```

### Verification Commands

```bash
# Check pipeline efficiency
gitlab-runner exec docker detect-changes --docker-image alpine/git

# Validate YAML syntax
yamllint .gitlab-ci.yml

# Test change detection locally
bash scripts/detect-changes.sh python
```

---

## Performance Benefits

### Before Optimization
- **All tests run on every change**: 15-20 minutes
- **Resource usage**: High (3-4 runners)
- **Feedback time**: Slow

### After Optimization  
- **Only relevant tests run**: 3-5 minutes average
- **Resource usage**: Optimized (1-2 runners)
- **Feedback time**: Fast

### Metrics Tracking

```yaml
# Add metrics collection
collect-metrics:
  stage: report
  script:
    - echo "PIPELINE_DURATION=$(($(date +%s) - $CI_PIPELINE_CREATED_AT))" >> metrics.env
    - echo "JOBS_RUN=$(echo $CI_JOB_NAME | wc -w)" >> metrics.env
    - echo "EFFICIENCY_SCORE=$((100 - (JOBS_RUN * 10)))" >> metrics.env
  artifacts:
    reports:
      dotenv: metrics.env
```

---

## Common Issues & Solutions

### Issue 1: Rules not working
**Problem**: Jobs still run when files haven't changed
**Solution**: Check `GIT_DEPTH` and ensure proper git history

### Issue 2: Changes not detected
**Problem**: File changes not triggering jobs  
**Solution**: Verify path patterns and use `git diff --name-only` to debug

### Issue 3: Child pipelines not triggering
**Problem**: Child pipelines fail to start
**Solution**: Check `strategy: depend` and file paths in trigger configuration

### Issue 4: Performance not improved
**Problem**: Pipeline still takes too long
**Solution**: Review parallel strategies and caching implementation

---

## Advanced Extensions

### 1. Kubernetes Deployment Conditions
```yaml
deploy-python-app:
  stage: deploy
  script:
    - kubectl apply -f k8s/python/
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      changes:
        - "templates/python/**/*"
        - "apps/python/**/*"
```

### 2. Environment-Specific Rules
```yaml
test-staging:
  script: ./deploy-staging.sh
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"
      changes:
        - "templates/**/*"
      when: always
```

### 3. Notification Rules
```yaml
notify-teams:
  script: ./notify-slack.sh "Python templates updated"
  rules:
    - changes:
        - "templates/python/**/*"
      when: on_failure
```

---

## Next Steps

After completing this lab, you should:

1. **Understand conditional execution patterns**
2. **Implement change-based testing**
3. **Optimize pipeline performance**
4. **Use dynamic pipeline generation**
5. **Implement child pipeline strategies**

Continue to advanced GitLab CI/CD topics or apply these patterns to your real-world projects.

## Useful References

- [GitLab CI/CD Rules Documentation](https://docs.gitlab.com/ee/ci/yaml/#rules)
- [GitLab CI/CD Changes Documentation](https://docs.gitlab.com/ee/ci/yaml/#ruleschanges)
- [Child Pipelines Documentation](https://docs.gitlab.com/ee/ci/parent_child_pipelines.html)
- [Pipeline Efficiency Best Practices](https://docs.gitlab.com/ee/ci/pipelines/pipeline_efficiency.html)

---

## Lab Completion Checklist

- [ ] Implemented basic conditional execution
- [ ] Created dynamic change detection  
- [ ] Set up child pipeline strategy
- [ ] Added performance optimizations
- [ ] Tested multi-language scenarios
- [ ] Verified caching strategies
- [ ] Documented performance improvements
- [ ] Created comprehensive test scripts