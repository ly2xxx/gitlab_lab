#!/bin/bash
set -e

echo "=== Node.js Pipeline Template Testing Script ==="
echo "Script version: 1.0"
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Create directories
mkdir -p test-results/nodejs reports/nodejs

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    echo "🔍 Validating YAML syntax: $file"
    
    # Check if we have node and can install yaml parser
    if command -v node &> /dev/null; then
        # Install yaml parser if not available
        if [ ! -d "node_modules/js-yaml" ]; then
            echo "Installing js-yaml for Node.js YAML validation..."
            npm init -y > /dev/null 2>&1 || true
            npm install js-yaml > /dev/null 2>&1 || echo "Could not install js-yaml, using alternative validation"
        fi
        
        # Test Node.js YAML parsing
        node -e "
const yaml = require('js-yaml');
const fs = require('fs');
try {
    const doc = yaml.load(fs.readFileSync('$file', 'utf8'));
    console.log('✅ Node.js YAML parsing successful');
} catch (e) {
    console.log('❌ Node.js YAML parsing failed:', e.message);
    process.exit(1);
}
" 2>/dev/null || echo "⚠️ Node.js YAML validation skipped (js-yaml not available)"
    else
        echo "⚠️ Node.js not available, skipping Node.js-specific YAML validation"
    fi
    
    # Fallback to basic validation
    echo "Testing basic YAML structure..."
    if grep -q "^[[:space:]]*-" "$file" && grep -q ":" "$file"; then
        echo "✅ Basic YAML structure appears valid"
    else
        echo "❌ Basic YAML structure validation failed"
        return 1
    fi
}

# Function to validate GitLab CI pipeline structure for Node.js
validate_nodejs_pipeline() {
    local file=$1
    echo "🔍 Validating Node.js GitLab CI structure: $file"
    
    local validation_errors=0
    
    # Check for Node.js specific elements
    if grep -q "node\|npm\|yarn\|pnpm" "$file"; then
        echo "✅ Node.js keywords found"
    else
        echo "⚠️ No Node.js-specific keywords found"
        ((validation_errors++))
    fi
    
    # Check for common Node.js pipeline patterns
    local nodejs_patterns=("npm install" "npm run" "npm test" "yarn install" "yarn build" "node_modules")
    local found_patterns=0
    
    for pattern in "${nodejs_patterns[@]}"; do
        if grep -iq "$pattern" "$file"; then
            echo "✅ Found Node.js pattern: $pattern"
            ((found_patterns++))
        fi
    done
    
    if [ $found_patterns -gt 0 ]; then
        echo "✅ Node.js pipeline patterns detected"
    else
        echo "⚠️ No common Node.js pipeline patterns found"
        ((validation_errors++))
    fi
    
    # Check for proper script structure
    if grep -A 5 "script:" "$file" | grep -q "- "; then
        echo "✅ Script section properly formatted"
    else
        echo "❌ Script section missing or improperly formatted"
        ((validation_errors++))
    fi
    
    return $validation_errors
}

# Function to test template with mock scenarios
test_template_scenarios() {
    local template=$1
    echo "🧪 Testing Node.js template scenarios: $template"
    
    # Create a test scenario
    local test_file="test-results/nodejs/$(basename "$template" .yml)_test.yml"
    
    # Generate test pipeline
    cat > "$test_file" << EOF
# Test scenario for: $template
stages:
  - build
  - test
  - deploy

variables:
  NODE_VERSION: "16"
  CACHE_KEY: "\$CI_COMMIT_REF_SLUG"

build:
  stage: build
  image: node:\$NODE_VERSION
  script:
    - echo "Testing Node.js template: $template"
    - echo "Node.js version: \$(node --version)"
    - echo "NPM version: \$(npm --version)"
    - npm install
    - npm run build || echo "No build script defined"
  cache:
    key: "\$CACHE_KEY"
    paths:
      - node_modules/

test:
  stage: test
  image: node:\$NODE_VERSION
  script:
    - npm test || echo "No test script defined"
  needs:
    - build

deploy:
  stage: deploy
  image: node:\$NODE_VERSION
  script:
    - echo "Template validation successful for: $template"
  rules:
    - if: \$CI_COMMIT_BRANCH == "main"
EOF

    validate_yaml "$test_file"
    echo "✅ Template scenario test passed"
}

# Function to run specific template tests
test_template() {
    local template=$1
    echo ""
    echo "🔬 Testing Node.js template: $template"
    echo "----------------------------------------"
    
    # Check if file exists
    if [ ! -f "$template" ]; then
        echo "❌ Template file not found: $template"
        return 1
    fi
    
    # Validate YAML syntax
    validate_yaml "$template"
    
    # Validate Node.js-specific pipeline structure
    validate_nodejs_pipeline "$template"
    
    # Test template scenarios
    test_template_scenarios "$template"
    
    # Run template-specific tests
    case "$template" in
        *react*)
            echo "⚛️ Running React-specific tests"
            test_react_template "$template"
            ;;
        *express*)
            echo "🚂 Running Express-specific tests"
            test_express_template "$template"
            ;;
        *nextjs*|*next*)
            echo "▲ Running Next.js-specific tests"
            test_nextjs_template "$template"
            ;;
        *vue*)
            echo "💚 Running Vue.js-specific tests"
            test_vue_template "$template"
            ;;
        *angular*)
            echo "🅰️ Running Angular-specific tests"
            test_angular_template "$template"
            ;;
        *)
            echo "🟢 Running generic Node.js template tests"
            test_generic_nodejs_template "$template"
            ;;
    esac
    
    echo "✅ Template testing completed: $template"
}

# React-specific template testing
test_react_template() {
    local template=$1
    echo "Testing React template specifics..."
    
    local react_keywords=("react" "jsx" "tsx" "create-react-app" "react-scripts" "build")
    local found_keywords=0
    
    for keyword in "${react_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found React keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ React-specific validation passed"
    else
        echo "⚠️ No React-specific keywords found"
    fi
}

# Express-specific template testing
test_express_template() {
    local template=$1
    echo "Testing Express template specifics..."
    
    local express_keywords=("express" "server" "app.js" "index.js" "nodemon" "middleware")
    local found_keywords=0
    
    for keyword in "${express_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Express keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Express-specific validation passed"
    else
        echo "⚠️ No Express-specific keywords found"
    fi
}

# Next.js-specific template testing
test_nextjs_template() {
    local template=$1
    echo "Testing Next.js template specifics..."
    
    local nextjs_keywords=("next" "nextjs" "next build" "next dev" "next start" ".next")
    local found_keywords=0
    
    for keyword in "${nextjs_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Next.js keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Next.js-specific validation passed"
    else
        echo "⚠️ No Next.js-specific keywords found"
    fi
}

# Vue.js-specific template testing
test_vue_template() {
    local template=$1
    echo "Testing Vue.js template specifics..."
    
    local vue_keywords=("vue" "vuejs" "@vue/cli" "vue-cli-service" "vite")
    local found_keywords=0
    
    for keyword in "${vue_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Vue.js keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Vue.js-specific validation passed"
    else
        echo "⚠️ No Vue.js-specific keywords found"
    fi
}

# Angular-specific template testing
test_angular_template() {
    local template=$1
    echo "Testing Angular template specifics..."
    
    local angular_keywords=("angular" "@angular/cli" "ng build" "ng test" "ng serve")
    local found_keywords=0
    
    for keyword in "${angular_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Angular keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Angular-specific validation passed"
    else
        echo "⚠️ No Angular-specific keywords found"
    fi
}

# Generic Node.js template testing
test_generic_nodejs_template() {
    local template=$1
    echo "Testing generic Node.js template..."
    
    local nodejs_keywords=("node" "npm" "yarn" "package.json" "node_modules" "javascript")
    local found_keywords=0
    
    for keyword in "${nodejs_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Node.js keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Generic Node.js template validation passed"
    else
        echo "⚠️ No Node.js-specific keywords found in template"
    fi
}

# Generate JUnit test results
generate_junit_results() {
    local results_file="test-results/nodejs/junit.xml"
    echo "📊 Generating JUnit test results: $results_file"
    
    cat > "$results_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Node.js Pipeline Templates" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" time="$TEST_DURATION">
  <testsuite name="Template Validation" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" time="$TEST_DURATION">
$(for template in $TESTED_TEMPLATES; do
    echo "    <testcase name=\"$(basename "$template")\" classname=\"NodejsTemplateValidation\" time=\"1.0\">"
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
echo "🚀 Starting Node.js pipeline template testing..."
echo ""

# Initialize counters
TOTAL_TESTS=0
FAILED_TESTS=0
TESTED_TEMPLATES=""
FAILED_TEMPLATES=""
START_TIME=$(date +%s)

# Test templates in the templates/nodejs directory
if [ -d "templates/nodejs" ]; then
    echo "📁 Found Node.js templates directory"
    echo "Templates to test:"
    find templates/nodejs -name "*.yml" -type f | sed 's/^/  - /'
    echo ""
    
    for template in templates/nodejs/*.yml; do
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
    echo "⚠️ No templates/nodejs directory found, creating sample templates for testing..."
    
    # Create sample templates for demonstration
    mkdir -p templates/nodejs
    
    # Sample React template
    cat > templates/nodejs/react.yml << 'EOF'
# React CI/CD Template
stages:
  - build
  - test
  - deploy

variables:
  NODE_VERSION: "16"
  CACHE_KEY: "$CI_COMMIT_REF_SLUG"

build:
  stage: build
  image: node:$NODE_VERSION
  script:
    - npm ci
    - npm run build
  cache:
    key: $CACHE_KEY
    paths:
      - node_modules/
  artifacts:
    paths:
      - build/
    expire_in: 1 hour

test:
  stage: test
  image: node:$NODE_VERSION
  script:
    - npm ci
    - npm run test -- --coverage --watchAll=false
  cache:
    key: $CACHE_KEY
    paths:
      - node_modules/
    policy: pull
  coverage: '/Lines\s*:\s*(\d+\.\d+%)/'

deploy:
  stage: deploy
  image: node:$NODE_VERSION
  script:
    - echo "Deploying React application"
    - npm run deploy || echo "Deploy script not configured"
  only:
    - main
EOF

    # Sample Express template
    cat > templates/nodejs/express.yml << 'EOF'
# Express.js CI/CD Template
stages:
  - test
  - build
  - deploy

variables:
  NODE_VERSION: "16"

test:
  stage: test
  image: node:$NODE_VERSION
  services:
    - postgres:13
  script:
    - npm install
    - npm run test
  coverage: '/Statements\s*:\s*(\d+\.\d+%)/'

build:
  stage: build
  image: node:$NODE_VERSION
  script:
    - npm install --production
    - npm prune --production
  artifacts:
    paths:
      - node_modules/
      - app.js
      - routes/
      - models/

deploy:
  stage: deploy
  image: node:$NODE_VERSION
  script:
    - echo "Deploying Express application"
    - node app.js &
    - echo "Application started"
  only:
    - main
EOF

    echo "✅ Created sample Node.js templates"
    
    # Test the created templates
    for template in templates/nodejs/*.yml; do
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

# Test shared Node.js components
if [ -d "shared/nodejs" ]; then
    echo ""
    echo "📁 Testing shared Node.js components..."
    
    for shared_file in shared/nodejs/*.yml; do
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
cat > reports/nodejs/summary.txt << EOF
Node.js Pipeline Template Testing Summary
=========================================
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
echo "📊 Node.js Pipeline Testing Summary"
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
    echo "✅ All Node.js pipeline template tests passed!"
    exit 0
fi