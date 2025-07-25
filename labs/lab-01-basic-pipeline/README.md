# Lab 1: Basic Pipeline Setup

## Objective
Learn the fundamentals of GitLab CI/CD by creating your first pipeline with a simple `.gitlab-ci.yml` file.

## Prerequisites
- GitLab account (GitLab.com or self-hosted)
- Basic understanding of YAML syntax
- Git knowledge

## What You'll Learn
- Basic `.gitlab-ci.yml` structure
- Understanding jobs and stages
- Pipeline execution basics
- GitLab CI/CD interface navigation

## Lab Steps

### Step 1: Create Your First Pipeline

Create a `.gitlab-ci.yml` file in your project root:

```yaml
# Basic pipeline with single job
hello_world:
  script:
    - echo "Hello, GitLab CI/CD!"
    - echo "Current date: $(date)"
    - echo "Current user: $(whoami)"
    - echo "Current directory: $(pwd)"
```

### Step 2: Understanding the Structure

The basic components:
- **Job name**: `hello_world` (can be any name)
- **script**: Commands to execute
- **Built-in variables**: `$CI_*` variables are available

### Step 3: Add More Jobs

Expand your pipeline:

```yaml
hello_world:
  script:
    - echo "Hello, GitLab CI/CD!"
    - echo "Pipeline ID: $CI_PIPELINE_ID"
    - echo "Commit SHA: $CI_COMMIT_SHA"

show_environment:
  script:
    - echo "Runner info:"
    - cat /etc/os-release || echo "Not a Linux system"
    - echo "Available tools:"
    - which git && git --version
    - which curl && curl --version
```

### Step 4: Pipeline Variables

Add variables to your pipeline:

```yaml
variables:
  GREETING: "Hello from GitLab CI/CD"
  PROJECT_NAME: "GitLab Tutorial"

hello_world:
  script:
    - echo "$GREETING"
    - echo "Project: $PROJECT_NAME"
    - echo "GitLab variables:"
    - echo "Project: $CI_PROJECT_NAME"
    - echo "Branch: $CI_COMMIT_REF_NAME"
    - echo "Runner: $CI_RUNNER_DESCRIPTION"
```

## Expected Results

1. Pipeline should execute successfully
2. Jobs run in parallel (no stages defined)
3. Output shows environment information
4. Variables are properly substituted

## Common Issues & Solutions

**Issue**: Pipeline doesn't start
- **Solution**: Check `.gitlab-ci.yml` syntax using GitLab's CI Lint tool

**Issue**: Job fails with "command not found"
- **Solution**: The command might not be available in the default runner image

**Issue**: Variables not showing values
- **Solution**: Ensure proper YAML indentation and variable names

## Next Steps

Proceed to [Lab 2: Stages and Jobs](../lab-02-stages-jobs/README.md) to learn about organizing your pipeline.

## Useful GitLab CI/CD Variables

| Variable | Description |
|----------|-------------|
| `$CI_PROJECT_NAME` | Project name |
| `$CI_COMMIT_SHA` | Commit SHA |
| `$CI_COMMIT_REF_NAME` | Branch or tag name |
| `$CI_PIPELINE_ID` | Pipeline ID |
| `$CI_JOB_NAME` | Current job name |
| `$CI_RUNNER_DESCRIPTION` | Runner description |