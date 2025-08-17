# GitLab Component Usage Patterns

This document explains different approaches for consuming GitLab CI components that have dependencies on external files.

## The Problem: Component Dependencies

When a GitLab component needs to include other files (like utility functions), there are limitations:

- **Component includes** (`component: host/project/name@version`) only fetch the YAML configuration
- **Local includes** within components fail when consumed externally because paths are resolved in the consumer's project context
- Error: `"Local file '../common-utils/echo.yml' does not exist!"`

## Solution Approaches

### Approach 1: Project Includes (Recommended)

**Use Case**: When you need access to multiple files from the external project

**Syntax**:
```yaml
include:
  - project: 'group/external-project'
    ref: main
    file: 'templates/component.yml'      # Main component template
  - project: 'group/external-project'  
    ref: main
    file: 'common-utils/utilities.yml'   # Required dependencies

stages:
  - build  # Define stages used by the component
```

**Example** (see `.gitlab-ci_sample-user.yml`):
```yaml
include:
  - project: 'root/gitlab-lab-11-git-ops'
    ref: main
    file: 'templates/helloworld.yml'      # Component template
  - project: 'root/gitlab-lab-11-git-ops'  
    ref: main
    file: 'common-utils/echo.yml'         # Echo utilities

stages:
  - build
```

**Advantages**:
- ✅ Solves the "local file does not exist" problem
- ✅ Can access multiple files from external project
- ✅ Path resolution works correctly
- ✅ Uses stable GitLab features
- ✅ Maintains file separation

**Disadvantages**:
- ❌ Loses component input validation
- ❌ No semantic versioning
- ❌ Manual file management required
- ❌ Consumer must know internal file structure

---

### Approach 2: Component Includes (Simple Components Only)

**Use Case**: When components are self-contained without external dependencies

**Syntax**:
```yaml
include:
  - component: host/group/project/component-name@version
    inputs:
      stage: "build"
      custom_param: "value"
```

**Example**:
```yaml
include:
  - component: host.docker.internal/root/gitlab-lab-11-git-ops/helloworld@main
    inputs:
      stage: "test"
```

**Requirements for this approach**:
- Component must embed all dependencies inline
- No external file dependencies
- All utilities included in the component YAML

**Advantages**:
- ✅ Semantic versioning support
- ✅ Input validation and typing
- ✅ GitLab catalog integration
- ✅ Cleaner consumer syntax

**Disadvantages**:
- ❌ Cannot access external files
- ❌ Code duplication if utilities are shared
- ❌ Larger component files

---

## Implementation Examples

### Project Include Implementation

**Consumer Project** (`.gitlab-ci.yml`):
```yaml
include:
  # Include both the component and its dependencies
  - project: 'shared/components'
    ref: main
    file: 'templates/hello-component.yml'
  - project: 'shared/components'
    ref: main  
    file: 'common-utils/echo.yml'

stages:
  - build
  - test

# Your custom jobs can also use the echo functions
custom-job:
  stage: test
  script:
    - eval "$ECHO_FUNCTIONS"
    - log_info "Custom job running"
```

**Component Project** (`templates/hello-component.yml`):
```yaml
spec:
  inputs:
    stage:
      default: build

---
# Component expects echo.yml to be included separately
hello:
  stage: $[[ inputs.stage ]]
  image: alpine
  script:
    - eval "$ECHO_FUNCTIONS"      # Functions from echo.yml
    - log_info "Hello from component!"
```

### Component Include Implementation (Alternative)

**Consumer Project** (`.gitlab-ci.yml`):
```yaml
include:
  - component: shared/components/hello@v1.0.0
    inputs:
      stage: "build"
```

**Component Project** (`templates/hello.yml`):
```yaml
spec:
  inputs:
    stage:
      default: build

---
variables:
  # Inline all dependencies
  ECHO_FUNCTIONS: |
    log_info() { echo -e "\033[32m[INFO] ℹ️ $1\033[0m"; }
    log_error() { echo -e "\033[31m[ERROR] ❌ $1\033[0m"; }

hello:
  stage: $[[ inputs.stage ]]
  image: alpine
  script:
    - eval "$ECHO_FUNCTIONS"
    - log_info "Hello from component!"
```

---

## Choosing the Right Approach

### Use Project Includes When:
- Component needs access to multiple external files
- You want to maintain file separation and reusability
- Dependencies are shared across multiple components
- You're okay with manual dependency management

### Use Component Includes When:
- Component is self-contained
- You want semantic versioning and input validation
- Component will be published to GitLab catalog
- Dependencies are small and component-specific

---

## Migration Path

If you currently have components with external dependencies:

1. **Short-term**: Use project includes to resolve immediate issues
2. **Medium-term**: Consider restructuring to embed small dependencies
3. **Long-term**: Monitor GitLab's CI/CD Steps feature for future solutions

---

## Troubleshooting

### "Local file does not exist" Error
- **Cause**: Component trying to use `local:` include when consumed externally
- **Solution**: Switch to project includes or inline the dependency

### Missing Variables or Functions
- **Cause**: Dependency file not included by consumer
- **Solution**: Ensure consumer includes all required files using project includes

### Version Mismatch Issues
- **Cause**: Using different refs/versions for component and dependencies
- **Solution**: Use same `ref:` value for all includes from the same project

---

## Future Considerations

GitLab is developing **CI/CD Steps** (experimental in 2024) which may provide better solutions for component dependencies. Monitor GitLab releases for updates on this feature.

For now, project includes provide the most reliable solution for components with external file dependencies.