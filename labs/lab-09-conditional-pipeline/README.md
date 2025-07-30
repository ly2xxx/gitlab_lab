# Lab 9: Conditional Pipeline Execution

## Overview

This lab demonstrates **conditional pipeline execution** in GitLab CI/CD. The pipeline intelligently runs only the relevant tests based on which files have changed, improving efficiency and reducing build times.

## Files

- `Calculator.java` - Simple Java calculator class
- `calculator.py` - Simple Python calculator class  
- `.gitlab-ci.yml` - GitLab CI configuration with conditional rules

## How It Works

The pipeline has three jobs:

1. **`java-test`** - Only runs when `Calculator.java` is modified
2. **`python-test`** - Only runs when `calculator.py` is modified  
3. **`test-both`** - Manual job to test both applications

### Conditional Rules

Each job uses GitLab CI's `rules` with the `changes` keyword:

```yaml
rules:
  - changes:
      - "Calculator.java"
    when: always
  - when: never
```

This ensures the job only runs when the specified file changes, otherwise it's skipped.

## Testing the Demo

### 1. Test Java Pipeline
```bash
# Modify the Java file
echo "// Updated Java file" >> Calculator.java
git add Calculator.java
git commit -m "Update Java calculator"
git push
```
**Result**: Only the `java-test` job will run

### 2. Test Python Pipeline  
```bash
# Modify the Python file
echo "# Updated Python file" >> calculator.py
git add calculator.py
git commit -m "Update Python calculator"
git push
```
**Result**: Only the `python-test` job will run

### 3. Test Both Applications
Navigate to your GitLab project → CI/CD → Pipelines → Click the latest pipeline → Click "Run" next to the `test-both` job.

**Result**: Both applications will be tested in a single job

## Benefits

- **Faster builds**: Only relevant tests run
- **Resource efficiency**: Reduced compute usage
- **Cleaner pipeline**: Less noise from irrelevant jobs
- **Better feedback**: Developers see only relevant results

## Key Concepts Demonstrated

- **File-based conditional execution** using `changes`
- **Pipeline optimization** with targeted testing
- **GitLab CI rules** with `when: always` and `when: never`
- **Multi-language support** in a single repository

This simple example shows how conditional pipelines can significantly improve CI/CD efficiency in larger, multi-language projects.