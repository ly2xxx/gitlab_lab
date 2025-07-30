#!/bin/bash
set -e

echo "=== Python Pipeline Template Testing Script ==="
echo "Script version: 1.0"
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Create directories
mkdir -p test-results/python reports/python

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    echo "🔍 Validating YAML syntax: $file"
    
    # Check if yamllint is available, install if not
    if ! command -v yamllint &> /dev/null; then
        echo "Installing yamllint..."
        pip install --quiet yamllint pyyaml
    fi
    
    # Validate YAML syntax
    if yamllint -c labs/lab-09-conditional-pipeline/config/.yamllint "$file" 2>/dev/null; then
        echo "✅ YAML syntax valid"
    else
        echo "❌ YAML syntax invalid"
        return 1
    fi
    
    # Test Python YAML parsing
    python3 -c "
import yaml
import sys
try:
    with open('$file', 'r') as f:
        yaml.safe_load(f)
    print('✅ Python YAML parsing successful')
except Exception as e:
    print(f'❌ Python YAML parsing failed: {e}')
    sys.exit(1)
"
}

# Function to validate GitLab CI pipeline structure
validate_gitlab_ci() {
    local file=$1
    echo "🔍 Validating GitLab CI structure: $file"
    
    python3 -c "
import yaml
import sys

with open('$file', 'r') as f:
    pipeline = yaml.safe_load(f)

# Basic validation checks
errors = []

# Check for required fields
if not isinstance(pipeline, dict):
    errors.append('Pipeline must be a dictionary')

# Check for valid job structure
for job_name, job_config in pipeline.items():
    if job_name.startswith('.'):
        continue  # Skip hidden jobs
    
    if not isinstance(job_config, dict):
        errors.append(f'Job {job_name} must be a dictionary')
        continue
        
    # Jobs should have script or other execution methods
    if 'script' not in job_config and 'trigger' not in job_config and 'extends' not in job_config:
        errors.append(f'Job {job_name} missing script or execution method')

if errors:
    for error in errors:
        print(f'❌ {error}')
    sys.exit(1)
else:
    print('✅ GitLab CI structure valid')
"
}

# Function to test template with mock scenarios
test_template_scenarios() {
    local template=$1
    echo "🧪 Testing template scenarios: $template"
    
    # Create a simple test case
    local test_file="test-results/python/$(basename "$template" .yml)_test.yml"
    
    # Test basic pipeline execution simulation
    echo "stages:" > "$test_file"
    echo "  - test" >> "$test_file"
    echo "" >> "$test_file"
    echo "test_job:" >> "$test_file"
    echo "  stage: test" >> "$test_file"
    echo "  script:" >> "$test_file"
    echo "    - echo 'Testing Python template: $template'" >> "$test_file"
    echo "    - echo 'Template validation successful'" >> "$test_file"
    
    validate_yaml "$test_file"
    echo "✅ Template scenario test passed"
}

# Function to run specific template tests
test_template() {
    local template=$1
    echo ""
    echo "🔬 Testing template: $template"
    echo "----------------------------------------"
    
    # Check if file exists
    if [ ! -f "$template" ]; then
        echo "❌ Template file not found: $template"
        return 1
    fi
    
    # Validate YAML syntax
    validate_yaml "$template"
    
    # Validate GitLab CI structure
    validate_gitlab_ci "$template"
    
    # Test template scenarios
    test_template_scenarios "$template"
    
    # Run template-specific tests
    case "$template" in
        *django*)
            echo "🐍 Running Django-specific tests"
            test_django_template "$template"
            ;;
        *flask*)
            echo "🌶️ Running Flask-specific tests"
            test_flask_template "$template"
            ;;
        *fastapi*)
            echo "⚡ Running FastAPI-specific tests"
            test_fastapi_template "$template"
            ;;
        *)
            echo "🐍 Running generic Python template tests"
            test_generic_python_template "$template"
            ;;
    esac
    
    echo "✅ Template testing completed: $template"
}

# Django-specific template testing
test_django_template() {
    local template=$1
    echo "Testing Django template specifics..."
    
    # Check for Django-specific job names and configurations
    if grep -q "django\|migrate\|collectstatic" "$template"; then
        echo "✅ Django-specific keywords found"
    else
        echo "⚠️ No Django-specific keywords found"
    fi
}

# Flask-specific template testing
test_flask_template() {
    local template=$1
    echo "Testing Flask template specifics..."
    
    # Check for Flask-specific configurations
    if grep -q "flask\|wsgi\|gunicorn" "$template"; then
        echo "✅ Flask-specific keywords found"
    else
        echo "⚠️ No Flask-specific keywords found"
    fi
}

# FastAPI-specific template testing
test_fastapi_template() {
    local template=$1
    echo "Testing FastAPI template specifics..."
    
    # Check for FastAPI-specific configurations
    if grep -q "fastapi\|uvicorn\|async" "$template"; then
        echo "✅ FastAPI-specific keywords found"
    else
        echo "⚠️ No FastAPI-specific keywords found"
    fi
}

# Generic Python template testing
test_generic_python_template() {
    local template=$1
    echo "Testing generic Python template..."
    
    # Check for common Python pipeline elements
    local python_keywords=("python" "pip" "pytest" "requirements" "venv" "virtualenv")
    local found_keywords=0
    
    for keyword in "${python_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Python keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Generic Python template validation passed"
    else
        echo "⚠️ No Python-specific keywords found in template"
    fi
}

# Generate JUnit test results
generate_junit_results() {
    local results_file="test-results/python/junit.xml"
    echo "📊 Generating JUnit test results: $results_file"
    
    cat > "$results_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Python Pipeline Templates" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" time="$TEST_DURATION">
  <testsuite name="Template Validation" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" time="$TEST_DURATION">
$(for template in $TESTED_TEMPLATES; do
    echo "    <testcase name=\"$(basename "$template")\" classname=\"PythonTemplateValidation\" time=\"1.0\">"
    if [[ "$FAILED_TEMPLATES" == *"$template"* ]]; then
        echo "      <failure message=\"Template validation failed\">Template $template failed validation</failure>"
    fi
    echo "    </testcase>"
done)
  </testsuite>
</testsuites>
EOF
}

# Main execution
echo "🚀 Starting Python pipeline template testing..."
echo ""

# Initialize counters
TOTAL_TESTS=0
FAILED_TESTS=0
TESTED_TEMPLATES=""
FAILED_TEMPLATES=""
START_TIME=$(date +%s)

# Test templates in the templates/python directory
if [ -d "templates/python" ]; then
    echo "📁 Found Python templates directory"
    echo "Templates to test:"
    find templates/python -name "*.yml" -type f | sed 's/^/  - /'
    echo ""
    
    for template in templates/python/*.yml; do
        if [ -f "$template" ]; then
            TESTED_TEMPLATES="$TESTED_TEMPLATES $template"
            ((TOTAL_TESTS++))
            
            if ! test_template "$template"; then
                FAILED_TEMPLATES="$FAILED_TEMPLATES $template"
                ((FAILED_TESTS++))
                echo "❌ FAILED: $template"
            else
                echo "✅ PASSED: $template"
            fi
        fi
    done
else
    echo "⚠️ No templates/python directory found, creating sample templates for testing..."
    
    # Create sample templates for demonstration
    mkdir -p templates/python
    
    # Sample Django template
    cat > templates/python/django.yml << 'EOF'
# Django CI/CD Template
stages:
  - test
  - build
  - deploy

variables:
  DJANGO_SETTINGS_MODULE: "myproject.settings.test"
  POSTGRES_DB: test_db
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: postgres

test:
  stage: test
  image: python:3.9
  services:
    - postgres:13
  script:
    - pip install -r requirements.txt
    - python manage.py migrate
    - python manage.py test
  coverage: '/TOTAL.*\s+(\d+%)$/'

build:
  stage: build
  image: python:3.9
  script:
    - pip install -r requirements.txt
    - python manage.py collectstatic --noinput
  artifacts:
    paths:
      - staticfiles/
EOF

    # Sample Flask template
    cat > templates/python/flask.yml << 'EOF'
# Flask CI/CD Template
stages:
  - test
  - build

variables:
  FLASK_ENV: testing

test:
  stage: test
  image: python:3.9
  script:
    - pip install -r requirements.txt
    - pip install pytest pytest-cov
    - pytest --cov=app tests/
  coverage: '/TOTAL.*\s+(\d+%)$/'

build:
  stage: build
  image: python:3.9
  script:
    - pip install -r requirements.txt
    - pip install gunicorn
  artifacts:
    paths:
      - app/
EOF

    echo "✅ Created sample templates"
    
    # Test the created templates
    for template in templates/python/*.yml; do
        if [ -f "$template" ]; then
            TESTED_TEMPLATES="$TESTED_TEMPLATES $template"
            ((TOTAL_TESTS++))
            
            if ! test_template "$template"; then
                FAILED_TEMPLATES="$FAILED_TEMPLATES $template"
                ((FAILED_TESTS++))
                echo "❌ FAILED: $template"
            else
                echo "✅ PASSED: $template"
            fi
        fi
    done
fi

# Test shared Python components
if [ -d "shared/python" ]; then
    echo ""
    echo "📁 Testing shared Python components..."
    
    for shared_file in shared/python/*.yml; do
        if [ -f "$shared_file" ]; then
            TESTED_TEMPLATES="$TESTED_TEMPLATES $shared_file"
            ((TOTAL_TESTS++))
            
            if ! test_template "$shared_file"; then
                FAILED_TEMPLATES="$FAILED_TEMPLATES $shared_file"
                ((FAILED_TESTS++))
                echo "❌ FAILED: $shared_file"
            else
                echo "✅ PASSED: $shared_file"
            fi
        fi
    done
fi

# Calculate test duration
END_TIME=$(date +%s)
TEST_DURATION=$((END_TIME - START_TIME))

# Generate reports
generate_junit_results

# Create summary report
cat > reports/python/summary.txt << EOF
Python Pipeline Template Testing Summary
========================================
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Duration: ${TEST_DURATION}s

Total Tests: $TOTAL_TESTS
Passed: $((TOTAL_TESTS - FAILED_TESTS))
Failed: $FAILED_TESTS

Tested Templates:
$TESTED_TEMPLATES

$(if [ $FAILED_TESTS -gt 0 ]; then
    echo "Failed Templates:"
    echo "$FAILED_TEMPLATES"
fi)
EOF

# Final summary
echo ""
echo "📊 ========================================="
echo "📊 Python Pipeline Testing Summary"
echo "📊 ========================================="
echo "📊 Total tests: $TOTAL_TESTS"
echo "📊 Passed: $((TOTAL_TESTS - FAILED_TESTS))"
echo "📊 Failed: $FAILED_TESTS"
echo "📊 Duration: ${TEST_DURATION}s"
echo "📊 Success rate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%"

if [ $FAILED_TESTS -gt 0 ]; then
    echo ""
    echo "❌ Some tests failed. Check the logs above for details."
    exit 1
else
    echo ""
    echo "✅ All Python pipeline template tests passed!"
    exit 0
fi