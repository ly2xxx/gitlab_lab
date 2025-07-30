#!/bin/bash
set -e

# Matrix Template Testing Script
# This script tests templates based on language and template type combinations

LANGUAGE=${1:-"unknown"}
TEMPLATE_TYPE=${2:-"basic"}

echo "=== Matrix Template Testing ==="
echo "Language: $LANGUAGE"
echo "Template Type: $TEMPLATE_TYPE"
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Create test results directory
mkdir -p test-results/matrix-${LANGUAGE}-${TEMPLATE_TYPE} reports/matrix

# Function to install language-specific tools
install_language_tools() {
    local lang=$1
    echo "🔧 Installing tools for $lang..."
    
    case "$lang" in
        "python")
            apk add --no-cache python3 py3-pip
            pip3 install pyyaml yamllint bandit safety || echo "Some Python tools not available"
            ;;
        "nodejs")
            apk add --no-cache nodejs npm
            npm install -g js-yaml eslint || echo "Some Node.js tools not available"
            ;;
        "java")
            apk add --no-cache openjdk11 maven python3 py3-pip
            pip3 install pyyaml || echo "YAML tools not available"
            ;;
        *)
            echo "⚠️ Unknown language: $lang"
            apk add --no-cache python3 py3-pip curl
            pip3 install pyyaml || echo "Basic tools installation failed"
            ;;
    esac
}

# Function to validate template based on language
validate_language_template() {
    local template=$1
    local lang=$2
    local type=$3
    
    echo "🔍 Validating $lang template: $template (type: $type)"
    
    # Basic YAML validation
    python3 -c "
import yaml
try:
    with open('$template', 'r') as f:
        pipeline = yaml.safe_load(f)
    print('✅ YAML syntax valid')
except Exception as e:
    print('❌ YAML syntax error:', e)
    exit(1)
" || return 1
    
    # Language-specific validation
    case "$lang" in
        "python")
            validate_python_template "$template" "$type"
            ;;
        "nodejs")
            validate_nodejs_template "$template" "$type"
            ;;
        "java")
            validate_java_template "$template" "$type"
            ;;
        *)
            echo "⚠️ Generic validation for unknown language"
            validate_generic_template "$template" "$type"
            ;;
    esac
}

# Python template validation
validate_python_template() {
    local template=$1
    local type=$2
    
    echo "🐍 Python-specific validation (type: $type)"
    
    # Check for Python keywords
    local python_keywords=("python" "pip" "requirements" "venv" "pytest")
    local found_keywords=0
    
    for keyword in "${python_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Python keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    # Type-specific validation
    case "$type" in
        "basic")
            if [ $found_keywords -ge 2 ]; then
                echo "✅ Basic Python template validation passed"
            else
                echo "❌ Basic Python template validation failed"
                return 1
            fi
            ;;
        "advanced")
            # Advanced templates should have more sophisticated patterns
            if grep -iq "cache\|artifacts\|coverage" "$template"; then
                echo "✅ Advanced Python template patterns found"
            else
                echo "❌ Advanced Python template patterns missing"
                return 1
            fi
            ;;
        *)
            echo "⚠️ Unknown Python template type: $type"
            ;;
    esac
}

# Node.js template validation
validate_nodejs_template() {
    local template=$1
    local type=$2
    
    echo "🟢 Node.js-specific validation (type: $type)"
    
    # Check for Node.js keywords
    local nodejs_keywords=("node" "npm" "yarn" "package.json" "javascript")
    local found_keywords=0
    
    for keyword in "${nodejs_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Node.js keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    # Type-specific validation
    case "$type" in
        "basic")
            if [ $found_keywords -ge 2 ]; then
                echo "✅ Basic Node.js template validation passed"
            else
                echo "❌ Basic Node.js template validation failed"
                return 1
            fi
            ;;
        "advanced")
            # Advanced templates should have caching, testing, etc.
            if grep -iq "cache\|test\|build" "$template"; then
                echo "✅ Advanced Node.js template patterns found"
            else
                echo "❌ Advanced Node.js template patterns missing"
                return 1
            fi
            ;;
        *)
            echo "⚠️ Unknown Node.js template type: $type"
            ;;
    esac
}

# Java template validation
validate_java_template() {
    local template=$1
    local type=$2
    
    echo "☕ Java-specific validation (type: $type)"
    
    # Check for Java keywords
    local java_keywords=("java" "maven" "gradle" "openjdk" "jar")
    local found_keywords=0
    
    for keyword in "${java_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Java keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    # Type-specific validation
    case "$type" in
        "basic")
            if [ $found_keywords -ge 2 ]; then
                echo "✅ Basic Java template validation passed"
            else
                echo "❌ Basic Java template validation failed"
                return 1
            fi
            ;;
        "advanced")
            # Advanced templates should have testing, packaging, etc.
            if grep -iq "test\|package\|deploy\|artifact" "$template"; then
                echo "✅ Advanced Java template patterns found"
            else
                echo "❌ Advanced Java template patterns missing"
                return 1
            fi
            ;;
        *)
            echo "⚠️ Unknown Java template type: $type"
            ;;
    esac
}

# Generic template validation
validate_generic_template() {
    local template=$1
    local type=$2
    
    echo "🔧 Generic template validation (type: $type)"
    
    # Check for basic CI/CD elements
    if grep -iq "script\|stage\|job" "$template"; then
        echo "✅ Basic CI/CD elements found"
    else
        echo "❌ Basic CI/CD elements missing"
        return 1
    fi
    
    # Type-specific validation
    case "$type" in
        "basic")
            if grep -iq "script:" "$template"; then
                echo "✅ Basic template validation passed"
            else
                echo "❌ Basic template validation failed"
                return 1
            fi
            ;;
        "advanced")
            if grep -iq "cache\|artifacts\|rules" "$template"; then
                echo "✅ Advanced template patterns found"
            else
                echo "❌ Advanced template patterns missing"
                return 1
            fi
            ;;
        *)
            echo "⚠️ Unknown template type: $type"
            ;;
    esac
}

# Function to test template performance characteristics
test_template_performance() {
    local template=$1
    local lang=$2
    local type=$3
    
    echo "⚡ Testing template performance characteristics..."
    
    # Check for caching
    if grep -iq "cache:" "$template"; then
        echo "✅ Caching configured"
    else
        echo "⚠️ No caching configured - may impact performance"
    fi
    
    # Check for parallel jobs
    if grep -iq "parallel:" "$template"; then
        echo "✅ Parallel execution configured"
    else
        echo "⚠️ No parallel execution - may be slower"
    fi
    
    # Check for optimized images
    local optimized_images=("slim" "alpine" "minimal")
    local has_optimized_image=false
    
    for image_type in "${optimized_images[@]}"; do
        if grep -iq "$image_type" "$template"; then
            echo "✅ Optimized image found: $image_type"
            has_optimized_image=true
            break
        fi
    done
    
    if [ "$has_optimized_image" = false ]; then
        echo "⚠️ Consider using optimized images (slim/alpine) for better performance"
    fi
}

# Function to generate matrix test report
generate_matrix_report() {
    local lang=$1
    local type=$2
    local tested_templates=$3
    local passed_templates=$4
    local failed_templates=$5
    
    local report_file="reports/matrix/matrix-${lang}-${type}-report.md"
    
    cat > "$report_file" << EOF
# Matrix Test Report: $lang - $type

**Language:** $lang  
**Template Type:** $type  
**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Test Duration:** ${TEST_DURATION}s

## Summary

This matrix test validated $lang templates of type $type.

## Test Results

- **Total Templates:** $(echo $tested_templates | wc -w)
- **Passed:** $(echo $passed_templates | wc -w)
- **Failed:** $(echo $failed_templates | wc -w)
- **Success Rate:** $(( ($(echo $passed_templates | wc -w) * 100) / $(echo $tested_templates | wc -w) ))%

## Templates Tested

### Passed Templates
$(for template in $passed_templates; do echo "- ✅ $template"; done)

### Failed Templates
$(for template in $failed_templates; do echo "- ❌ $template"; done)

## Validation Criteria

### $lang-Specific Checks
- Language-appropriate keywords and patterns
- Build tool configuration
- Testing framework presence
- Dependency management

### $type-Specific Checks
$(case "$type" in
    "basic")
        echo "- Basic CI/CD structure"
        echo "- Essential script commands"
        echo "- Minimal required configuration"
        ;;
    "advanced")
        echo "- Advanced CI/CD patterns"
        echo "- Caching configuration"
        echo "- Artifact management"
        echo "- Performance optimizations"
        ;;
esac)

## Performance Analysis

- Caching: $(grep -l "cache:" $tested_templates | wc -l)/$(echo $tested_templates | wc -w) templates
- Parallel execution: $(grep -l "parallel:" $tested_templates | wc -l)/$(echo $tested_templates | wc -w) templates
- Optimized images: $(grep -l -E "(slim|alpine|minimal)" $tested_templates | wc -l)/$(echo $tested_templates | wc -w) templates

## Recommendations

$(if [ $(echo $failed_templates | wc -w) -gt 0 ]; then
    echo "- Review and fix failed templates"
    echo "- Ensure language-specific patterns are properly implemented"
fi)
- Consider adding caching to improve performance
- Use optimized container images where possible
- Implement parallel execution for faster builds

EOF

    echo "📊 Matrix report generated: $report_file"
}

# Main execution starts here
echo "🚀 Starting matrix template testing..."

# Install language-specific tools
install_language_tools "$LANGUAGE"

# Initialize counters
TESTED_TEMPLATES=""
PASSED_TEMPLATES=""
FAILED_TEMPLATES=""
TOTAL_TESTS=0
FAILED_TESTS=0
START_TIME=$(date +%s)

# Find templates to test
template_pattern="templates/${LANGUAGE}/*${TEMPLATE_TYPE}*.yml"
template_dir="templates/${LANGUAGE}"

# If no specific pattern matches, test all templates in the language directory
if [ -d "$template_dir" ]; then
    echo "📁 Found template directory: $template_dir"
    
    # First try to find templates matching the specific type
    specific_templates=$(find "$template_dir" -name "*${TEMPLATE_TYPE}*.yml" -type f 2>/dev/null || true)
    
    if [ -n "$specific_templates" ]; then
        echo "🎯 Found specific templates for type '$TEMPLATE_TYPE':"
        echo "$specific_templates" | sed 's/^/  - /'
        template_list="$specific_templates"
    else
        echo "🔍 No specific templates found for type '$TEMPLATE_TYPE', testing all templates in $template_dir"
        template_list=$(find "$template_dir" -name "*.yml" -type f 2>/dev/null || true)
        
        if [ -n "$template_list" ]; then
            echo "📋 Templates to test:"
            echo "$template_list" | sed 's/^/  - /'
        fi
    fi
    
    # Test each template
    for template in $template_list; do
        if [ -f "$template" ]; then
            echo ""
            echo "🧪 Testing template: $template"
            echo "----------------------------------------"
            
            TESTED_TEMPLATES="$TESTED_TEMPLATES $template"
            ((TOTAL_TESTS++))
            
            # Validate the template
            if validate_language_template "$template" "$LANGUAGE" "$TEMPLATE_TYPE"; then
                # Test performance characteristics
                test_template_performance "$template" "$LANGUAGE" "$TEMPLATE_TYPE"
                
                PASSED_TEMPLATES="$PASSED_TEMPLATES $template"
                echo "✅ PASSED: $template"
            else
                FAILED_TEMPLATES="$FAILED_TEMPLATES $template"
                ((FAILED_TESTS++))
                echo "❌ FAILED: $template"
            fi
        fi
    done
else
    echo "⚠️ Template directory not found: $template_dir"
    echo "Creating sample template for testing..."
    
    # Create a sample template for testing
    mkdir -p "$template_dir"
    sample_template="$template_dir/sample-${TEMPLATE_TYPE}.yml"
    
    case "$LANGUAGE" in
        "python")
            cat > "$sample_template" << 'EOF'
# Sample Python Template
stages:
  - test
  - build

test:
  stage: test
  image: python:3.9
  script:
    - pip install -r requirements.txt
    - python -m pytest tests/
  cache:
    paths:
      - .cache/pip/

build:
  stage: build
  image: python:3.9
  script:
    - python setup.py build
  artifacts:
    paths:
      - dist/
EOF
            ;;
        "nodejs")
            cat > "$sample_template" << 'EOF'
# Sample Node.js Template
stages:
  - test
  - build

test:
  stage: test
  image: node:16
  script:
    - npm ci
    - npm test
  cache:
    paths:
      - node_modules/

build:
  stage: build
  image: node:16
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
EOF
            ;;
        "java")
            cat > "$sample_template" << 'EOF'
# Sample Java Template
stages:
  - test
  - package

test:
  stage: test
  image: openjdk:11
  script:
    - mvn test
  cache:
    paths:
      - .m2/repository/

package:
  stage: package
  image: openjdk:11
  script:
    - mvn package
  artifacts:
    paths:
      - target/*.jar
EOF
            ;;
    esac
    
    echo "✅ Created sample template: $sample_template"
    
    # Test the sample template
    TESTED_TEMPLATES="$sample_template"
    TOTAL_TESTS=1
    
    if validate_language_template "$sample_template" "$LANGUAGE" "$TEMPLATE_TYPE"; then
        test_template_performance "$sample_template" "$LANGUAGE" "$TEMPLATE_TYPE"
        PASSED_TEMPLATES="$sample_template"
        echo "✅ PASSED: $sample_template"
    else
        FAILED_TEMPLATES="$sample_template"
        FAILED_TESTS=1
        echo "❌ FAILED: $sample_template"
    fi
fi

# Calculate test duration
END_TIME=$(date +%s)
TEST_DURATION=$((END_TIME - START_TIME))

# Generate JUnit results
junit_file="test-results/matrix-${LANGUAGE}-${TEMPLATE_TYPE}/junit.xml"
cat > "$junit_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Matrix Tests: $LANGUAGE - $TEMPLATE_TYPE" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" time="$TEST_DURATION">
  <testsuite name="Template Validation" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" time="$TEST_DURATION">
$(for template in $TESTED_TEMPLATES; do
    echo "    <testcase name=\"$(basename "$template")\" classname=\"MatrixTemplateValidation\" time=\"1.0\">"
    if [[ "$FAILED_TEMPLATES" == *"$template"* ]]; then
        echo "      <failure message=\"Template validation failed\">Template $template failed matrix validation</failure>"
    fi
    echo "    </testcase>"
done)
  </testsuite>
</testsuites>
EOF

# Generate matrix report
generate_matrix_report "$LANGUAGE" "$TEMPLATE_TYPE" "$TESTED_TEMPLATES" "$PASSED_TEMPLATES" "$FAILED_TEMPLATES"

# Final summary
echo ""
echo "📊 ========================================="
echo "📊 Matrix Testing Summary"
echo "📊 ========================================="
echo "📊 Language: $LANGUAGE"
echo "📊 Template Type: $TEMPLATE_TYPE"
echo "📊 Total tests: $TOTAL_TESTS"
echo "📊 Passed: $((TOTAL_TESTS - FAILED_TESTS))"
echo "📊 Failed: $FAILED_TESTS"
echo "📊 Duration: ${TEST_DURATION}s"
if [ $TOTAL_TESTS -gt 0 ]; then
    echo "📊 Success rate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%"
fi

if [ $FAILED_TESTS -gt 0 ]; then
    echo ""
    echo "❌ Some matrix tests failed. Check the logs above for details."
    exit 1
else
    echo ""
    echo "✅ All matrix tests passed!"
    exit 0
fi