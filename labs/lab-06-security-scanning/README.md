# Lab 6: Security Scanning

## Objective
Implement comprehensive security scanning in your GitLab CI/CD pipeline, including SAST, DAST, dependency scanning, and container security.

## Prerequisites
- Completed [Lab 5: Testing Integration](../lab-05-testing-integration/README.md)
- Understanding of security concepts
- Basic knowledge of security vulnerabilities

## What You'll Learn
- Static Application Security Testing (SAST)
- Dynamic Application Security Testing (DAST)
- Dependency vulnerability scanning
- Container image security scanning
- Secret detection in code
- License compliance checking
- Security report interpretation
- Implementing security gates

## GitLab Security Features

GitLab provides comprehensive security scanning capabilities:

### Built-in Security Scanners
1. **SAST** - Static code analysis
2. **DAST** - Dynamic application testing
3. **Dependency Scanning** - Third-party library vulnerabilities
4. **Container Scanning** - Docker image vulnerabilities
5. **Secret Detection** - Hardcoded secrets in code
6. **License Compliance** - Open source license checking
7. **Coverage-guided Fuzzing** - Input validation testing

### Security Dashboard
- Vulnerability management
- Security trends and metrics
- Compliance reporting
- Risk assessment

## Lab Steps

### Step 1: Basic Security Scanning Setup

```yaml
# Include GitLab security templates
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/DAST.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/Container-Scanning.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml
  - template: Security/License-Scanning.gitlab-ci.yml

stages:
  - build
  - test
  - security
  - deploy

variables:
  # Security configuration
  SAST_ENABLED: "true"
  DAST_ENABLED: "true"
  DEPENDENCY_SCANNING_ENABLED: "true"
  CONTAINER_SCANNING_ENABLED: "true"
  SECRET_DETECTION_ENABLED: "true"
  
  # DAST configuration
  DAST_WEBSITE: "https://example.com"
  DAST_FULL_SCAN_ENABLED: "true"
```

### Step 2: Custom SAST Configuration

```yaml
# Custom SAST job with specific rules
sast_custom:
  extends: sast
  variables:
    SAST_EXCLUDED_PATHS: "tests/, docs/, *.md"
    SAST_ANALYZER_IMAGES: |
      bandit
      eslint
      nodejs-scan
      semgrep
  rules:
    - if: $CI_COMMIT_BRANCH
    - if: $CI_MERGE_REQUEST_IID
  artifacts:
    reports:
      sast: gl-sast-report.json
    when: always
```

### Step 3: Dependency Scanning with Custom Rules

```yaml
# Enhanced dependency scanning
dependency_scanning_enhanced:
  extends: .dependency_scanning
  variables:
    DS_EXCLUDED_PATHS: "tests/, docs/"
    DS_ANALYZER_IMAGES: |
      gemnasium
      retire-js
      gemnasium-maven
      gemnasium-python
  before_script:
    - echo "Starting dependency vulnerability scan..."
  script:
    - /analyzer run
  after_script:
    - echo "Dependency scan completed"
  artifacts:
    reports:
      dependency_scanning: gl-dependency-scanning-report.json
    when: always
```

### Step 4: Container Security Scanning

```yaml
# Container scanning for Docker images
container_scanning_custom:
  stage: security
  image: registry.gitlab.com/security-products/container-scanning:latest
  variables:
    CI_APPLICATION_REPOSITORY: $CI_REGISTRY_IMAGE
    CI_APPLICATION_TAG: $CI_COMMIT_SHA
    CLAIR_DB_CONNECTION_STRING: "postgresql://postgres:password@postgres:5432/postgres?sslmode=disable&statement_timeout=60000"
  services:
    - name: postgres:11
      alias: postgres
      variables:
        POSTGRES_PASSWORD: password
  script:
    - /analyzer run
  artifacts:
    reports:
      container_scanning: gl-container-scanning-report.json
    when: always
  dependencies:
    - build_docker_image
```

### Step 5: Dynamic Application Security Testing (DAST)

```yaml
# DAST configuration for running application
dast_webapp:
  stage: security
  image: registry.gitlab.com/security-products/dast:latest
  variables:
    DAST_WEBSITE: $CI_ENVIRONMENT_URL
    DAST_FULL_SCAN_ENABLED: "true"
    DAST_ZAP_LOG_CONFIGURATION: "log4j2-debug.properties"
    DAST_AUTH_URL: "$CI_ENVIRONMENT_URL/login"
    DAST_USERNAME: "testuser"
    DAST_PASSWORD: "testpass"
    DAST_USERNAME_FIELD: "username"
    DAST_PASSWORD_FIELD: "password"
  script:
    - /analyze
  artifacts:
    reports:
      dast: gl-dast-report.json
    when: always
  environment:
    name: test
    url: https://test.example.com
```

### Step 6: Secret Detection

```yaml
# Custom secret detection with additional patterns
secret_detection_enhanced:
  extends: .secret-analyzer
  variables:
    SECRET_DETECTION_EXCLUDED_PATHS: "tests/, docs/"
    SECRET_DETECTION_HISTORIC_SCAN: "true"
  script:
    - echo "Scanning for secrets in repository..."
    - /analyzer run
    - echo "Secret detection completed"
  artifacts:
    reports:
      secret_detection: gl-secret-detection-report.json
    when: always
  rules:
    - if: $CI_COMMIT_BRANCH
    - if: $CI_MERGE_REQUEST_IID
```

### Step 7: License Compliance

```yaml
# License compliance scanning
license_scanning_custom:
  extends: .license_scanning
  variables:
    LicenseManagement_ENABLED: "true"
    LICENSE_FINDER_CLI_OPTS: "--aggregate-paths=. --format=json"
  script:
    - /run.sh analyze .
  artifacts:
    reports:
      license_management: gl-license-management-report.json
    when: always
```

### Step 8: Security Quality Gates

```yaml
# Security gate that fails pipeline on high/critical vulnerabilities
security_gate:
  stage: security
  image: alpine:latest
  dependencies:
    - sast_custom
    - dependency_scanning_enhanced
    - container_scanning_custom
  before_script:
    - apk add --no-cache jq curl
  script:
    - echo "=== Security Quality Gate ==="
    
    # Check SAST results
    - |
      if [ -f "gl-sast-report.json" ]; then
        SAST_HIGH=$(jq '.vulnerabilities[] | select(.severity == "High" or .severity == "Critical") | .severity' gl-sast-report.json | wc -l)
        echo "SAST High/Critical vulnerabilities: $SAST_HIGH"
        if [ "$SAST_HIGH" -gt 0 ]; then
          echo "❌ SAST security gate failed: $SAST_HIGH high/critical vulnerabilities found"
          GATE_FAILED=true
        fi
      fi
    
    # Check Dependency Scanning results
    - |
      if [ -f "gl-dependency-scanning-report.json" ]; then
        DEP_HIGH=$(jq '.vulnerabilities[] | select(.severity == "High" or .severity == "Critical") | .severity' gl-dependency-scanning-report.json | wc -l)
        echo "Dependency High/Critical vulnerabilities: $DEP_HIGH"
        if [ "$DEP_HIGH" -gt 0 ]; then
          echo "❌ Dependency security gate failed: $DEP_HIGH high/critical vulnerabilities found"
          GATE_FAILED=true
        fi
      fi
    
    # Check Container Scanning results
    - |
      if [ -f "gl-container-scanning-report.json" ]; then
        CONTAINER_HIGH=$(jq '.vulnerabilities[] | select(.severity == "High" or .severity == "Critical") | .severity' gl-container-scanning-report.json | wc -l)
        echo "Container High/Critical vulnerabilities: $CONTAINER_HIGH"
        if [ "$CONTAINER_HIGH" -gt 0 ]; then
          echo "⚠️  Container security gate warning: $CONTAINER_HIGH high/critical vulnerabilities found"
        fi
      fi
    
    # Final gate decision
    - |
      if [ "$GATE_FAILED" = "true" ]; then
        echo "❌ Security quality gate FAILED"
        exit 1
      else
        echo "✅ Security quality gate PASSED"
      fi
  allow_failure: false
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_MERGE_REQUEST_IID
```

### Step 9: Custom Security Tools Integration

```yaml
# Custom security scanning with third-party tools
custom_security_scan:
  stage: security
  image: node:18
  before_script:
    - npm install -g audit-ci snyk
  script:
    - echo "=== Custom Security Scanning ==="
    
    # NPM Audit with audit-ci
    - echo "Running enhanced NPM audit..."
    - audit-ci --config audit-ci.json
    
    # Snyk vulnerability scanning
    - echo "Running Snyk security scan..."
    - snyk auth $SNYK_TOKEN
    - snyk test --json > snyk-report.json || true
    - snyk monitor --project-name=$CI_PROJECT_NAME
    
    # OWASP Dependency Check (if available)
    - echo "Custom security scan completed"
  artifacts:
    when: always
    paths:
      - snyk-report.json
      - audit-ci-report.json
    expire_in: 1 week
  allow_failure: true
```

### Step 10: Security Report Aggregation

```yaml
# Aggregate all security reports
security_report_summary:
  stage: security
  image: alpine:latest
  dependencies:
    - sast_custom
    - dependency_scanning_enhanced
    - container_scanning_custom
    - secret_detection_enhanced
  before_script:
    - apk add --no-cache jq
  script:
    - echo "=== Security Report Summary ==="
    
    # Create consolidated security report
    - echo "# Security Scan Summary" > security-summary.md
    - echo "" >> security-summary.md
    - echo "Generated: $(date)" >> security-summary.md
    - echo "Pipeline: $CI_PIPELINE_ID" >> security-summary.md
    - echo "Commit: $CI_COMMIT_SHA" >> security-summary.md
    - echo "" >> security-summary.md
    
    # SAST Summary
    - |
      if [ -f "gl-sast-report.json" ]; then
        echo "## SAST (Static Application Security Testing)" >> security-summary.md
        SAST_TOTAL=$(jq '.vulnerabilities | length' gl-sast-report.json)
        SAST_HIGH=$(jq '[.vulnerabilities[] | select(.severity == "High" or .severity == "Critical")] | length' gl-sast-report.json)
        echo "- Total vulnerabilities: $SAST_TOTAL" >> security-summary.md
        echo "- High/Critical: $SAST_HIGH" >> security-summary.md
        echo "" >> security-summary.md
      fi
    
    # Dependency Scanning Summary
    - |
      if [ -f "gl-dependency-scanning-report.json" ]; then
        echo "## Dependency Scanning" >> security-summary.md
        DEP_TOTAL=$(jq '.vulnerabilities | length' gl-dependency-scanning-report.json)
        DEP_HIGH=$(jq '[.vulnerabilities[] | select(.severity == "High" or .severity == "Critical")] | length' gl-dependency-scanning-report.json)
        echo "- Total vulnerabilities: $DEP_TOTAL" >> security-summary.md
        echo "- High/Critical: $DEP_HIGH" >> security-summary.md
        echo "" >> security-summary.md
      fi
    
    # Container Scanning Summary
    - |
      if [ -f "gl-container-scanning-report.json" ]; then
        echo "## Container Scanning" >> security-summary.md
        CONTAINER_TOTAL=$(jq '.vulnerabilities | length' gl-container-scanning-report.json)
        CONTAINER_HIGH=$(jq '[.vulnerabilities[] | select(.severity == "High" or .severity == "Critical")] | length' gl-container-scanning-report.json)
        echo "- Total vulnerabilities: $CONTAINER_TOTAL" >> security-summary.md
        echo "- High/Critical: $CONTAINER_HIGH" >> security-summary.md
        echo "" >> security-summary.md
      fi
    
    # Secret Detection Summary
    - |
      if [ -f "gl-secret-detection-report.json" ]; then
        echo "## Secret Detection" >> security-summary.md
        SECRET_TOTAL=$(jq '.vulnerabilities | length' gl-secret-detection-report.json)
        echo "- Secrets found: $SECRET_TOTAL" >> security-summary.md
        echo "" >> security-summary.md
      fi
    
    - cat security-summary.md
  artifacts:
    when: always
    paths:
      - security-summary.md
    expire_in: 1 month
    expose_as: "Security Summary Report"
```

## Security Configuration Files

### SAST Rules Configuration

```yaml
# .gitlab/sast-rules.yml
rules:
  - id: "javascript-eval"
    pattern: "eval\\("
    message: "Use of eval() function detected"
    severity: "High"
    languages: ["javascript"]
  
  - id: "sql-injection"
    pattern: "SELECT.*\\+.*FROM"
    message: "Possible SQL injection vulnerability"
    severity: "Critical"
    languages: ["javascript", "python"]
```

### Secret Detection Patterns

```yaml
# .gitlab/secret-detection-rules.yml
rules:
  - id: "custom-api-key"
    description: "Custom API Key Pattern"
    regex: "api[_-]?key[_-]?=[_-]?['\"][0-9a-zA-Z]{32,}['\"]?"
    tags: ["api", "key"]
  
  - id: "database-url"
    description: "Database Connection String"
    regex: "(postgresql|mysql|mongodb)://[^\\s]+"
    tags: ["database", "connection"]
```

## Security Best Practices

### 1. Pipeline Security
- Use least privilege access
- Store secrets in GitLab variables
- Enable protected branches
- Require approvals for security changes

### 2. Code Security
- Regular dependency updates
- Input validation
- Output encoding
- Secure authentication

### 3. Infrastructure Security
- Container image scanning
- Network security
- Access controls
- Monitoring and logging

### 4. Security Testing
- Shift-left security testing
- Automated security scans
- Regular penetration testing
- Security code reviews

## Common Security Vulnerabilities

### OWASP Top 10
1. Injection flaws
2. Broken authentication
3. Sensitive data exposure
4. XML external entities (XXE)
5. Broken access control
6. Security misconfiguration
7. Cross-site scripting (XSS)
8. Insecure deserialization
9. Using components with known vulnerabilities
10. Insufficient logging and monitoring

## Interpreting Security Reports

### Vulnerability Severity Levels
- **Critical**: Immediate action required
- **High**: Fix within days
- **Medium**: Fix within weeks
- **Low**: Fix within months
- **Info**: Awareness, no immediate action

### Report Sections
- Executive summary
- Vulnerability details
- Remediation guidance
- Risk assessment
- Compliance status

## Expected Results

1. **SAST Reports**: Code vulnerabilities identified
2. **DAST Reports**: Runtime security issues found
3. **Dependency Reports**: Third-party vulnerabilities listed
4. **Container Reports**: Image security assessment
5. **Secret Detection**: Hardcoded secrets identified
6. **Security Dashboard**: Centralized vulnerability management

## Next Steps

Proceed to [Lab 7: Advanced Pipeline Patterns](../lab-07-advanced-patterns/README.md) to learn about complex pipeline architectures and advanced GitLab CI/CD features.

## Reference

- [GitLab Security Documentation](https://docs.gitlab.com/ee/user/application_security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Security Best Practices](https://docs.gitlab.com/ee/security/)
- [Vulnerability Reports](https://docs.gitlab.com/ee/user/application_security/vulnerability_report/)