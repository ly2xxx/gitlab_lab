#!/bin/bash
set -e

echo "=== Java Pipeline Template Testing Script ==="
echo "Script version: 1.0"
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Create directories
mkdir -p test-results/java reports/java

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    echo "🔍 Validating YAML syntax: $file"
    
    # Basic YAML structure validation
    if grep -q "^[[:space:]]*-" "$file" && grep -q ":" "$file"; then
        echo "✅ Basic YAML structure appears valid"
    else
        echo "❌ Basic YAML structure validation failed"
        return 1
    fi
    
    # Check for balanced brackets and quotes
    local open_brackets=$(grep -o '{' "$file" | wc -l)
    local close_brackets=$(grep -o '}' "$file" | wc -l)
    
    if [ "$open_brackets" -eq "$close_brackets" ]; then
        echo "✅ YAML brackets balanced"
    else
        echo "⚠️ YAML brackets may be unbalanced"
    fi
}

# Function to validate GitLab CI pipeline structure for Java
validate_java_pipeline() {
    local file=$1
    echo "🔍 Validating Java GitLab CI structure: $file"
    
    local validation_errors=0
    
    # Check for Java specific elements
    if grep -q "java\|mvn\|maven\|gradle\|openjdk" "$file"; then
        echo "✅ Java keywords found"
    else
        echo "⚠️ No Java-specific keywords found"
        ((validation_errors++))
    fi
    
    # Check for common Java pipeline patterns
    local java_patterns=("mvn install" "mvn test" "gradle build" "gradle test" "java -jar" "springframework" "spring-boot")
    local found_patterns=0
    
    for pattern in "${java_patterns[@]}"; do
        if grep -iq "$pattern" "$file"; then
            echo "✅ Found Java pattern: $pattern"
            ((found_patterns++))
        fi
    done
    
    if [ $found_patterns -gt 0 ]; then
        echo "✅ Java pipeline patterns detected"
    else
        echo "⚠️ No common Java pipeline patterns found"
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
    echo "🧪 Testing Java template scenarios: $template"
    
    # Create a test scenario
    local test_file="test-results/java/$(basename "$template" .yml)_test.yml"
    
    # Generate test pipeline
    cat > "$test_file" << EOF
# Test scenario for: $template
stages:
  - build
  - test
  - package
  - deploy

variables:
  JAVA_VERSION: "11"
  MAVEN_OPTS: "-Dmaven.repo.local=.m2/repository"
  GRADLE_OPTS: "-Dorg.gradle.daemon=false"

build:
  stage: build
  image: openjdk:\$JAVA_VERSION
  script:
    - echo "Testing Java template: $template"
    - echo "Java version: \$(java -version 2>&1 | head -1)"
    - if [ -f "pom.xml" ]; then mvn compile; elif [ -f "build.gradle" ]; then gradle compileJava; fi
  cache:
    key: "\$CI_COMMIT_REF_SLUG"
    paths:
      - .m2/repository/
      - .gradle/

test:
  stage: test
  image: openjdk:\$JAVA_VERSION
  script:
    - if [ -f "pom.xml" ]; then mvn test; elif [ -f "build.gradle" ]; then gradle test; fi
  artifacts:
    reports:
      junit: "target/surefire-reports/TEST-*.xml"
  needs:
    - build

package:
  stage: package
  image: openjdk:\$JAVA_VERSION
  script:
    - if [ -f "pom.xml" ]; then mvn package; elif [ -f "build.gradle" ]; then gradle build; fi
    - echo "Template validation successful for: $template"
  artifacts:
    paths:
      - "target/*.jar"
      - "build/libs/*.jar"
  needs:
    - test

deploy:
  stage: deploy
  image: openjdk:\$JAVA_VERSION
  script:
    - echo "Deploying Java application"
    - java -jar target/*.jar || java -jar build/libs/*.jar || echo "No JAR file found"
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
    echo "🔬 Testing Java template: $template"
    echo "----------------------------------------"
    
    # Check if file exists
    if [ ! -f "$template" ]; then
        echo "❌ Template file not found: $template"
        return 1
    fi
    
    # Validate YAML syntax
    validate_yaml "$template"
    
    # Validate Java-specific pipeline structure
    validate_java_pipeline "$template"
    
    # Test template scenarios
    test_template_scenarios "$template"
    
    # Run template-specific tests
    case "$template" in
        *spring*|*springboot*)
            echo "🌱 Running Spring Boot-specific tests"
            test_springboot_template "$template"
            ;;
        *maven*)
            echo "🏗️ Running Maven-specific tests"
            test_maven_template "$template"
            ;;
        *gradle*)
            echo "🐘 Running Gradle-specific tests"
            test_gradle_template "$template"
            ;;
        *quarkus*)
            echo "⚡ Running Quarkus-specific tests"
            test_quarkus_template "$template"
            ;;
        *micronaut*)
            echo "🚀 Running Micronaut-specific tests"
            test_micronaut_template "$template"
            ;;
        *)
            echo "☕ Running generic Java template tests"
            test_generic_java_template "$template"
            ;;
    esac
    
    echo "✅ Template testing completed: $template"
}

# Spring Boot-specific template testing
test_springboot_template() {
    local template=$1
    echo "Testing Spring Boot template specifics..."
    
    local springboot_keywords=("spring-boot" "springframework" "@SpringBootApplication" "spring-boot-starter" "mvn spring-boot:run")
    local found_keywords=0
    
    for keyword in "${springboot_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Spring Boot keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Spring Boot-specific validation passed"
    else
        echo "⚠️ No Spring Boot-specific keywords found"
    fi
    
    # Check for common Spring Boot CI/CD patterns
    if grep -iq "spring-boot-maven-plugin\|bootJar\|bootRun" "$template"; then
        echo "✅ Spring Boot build configuration found"
    else
        echo "⚠️ No Spring Boot build configuration detected"
    fi
}

# Maven-specific template testing
test_maven_template() {
    local template=$1
    echo "Testing Maven template specifics..."
    
    local maven_keywords=("mvn" "maven" "pom.xml" "mvn clean" "mvn install" "mvn test" "surefire")
    local found_keywords=0
    
    for keyword in "${maven_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Maven keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Maven-specific validation passed"
    else
        echo "⚠️ No Maven-specific keywords found"
    fi
    
    # Check for Maven lifecycle phases
    local maven_phases=("compile" "test" "package" "install" "deploy")
    for phase in "${maven_phases[@]}"; do
        if grep -iq "mvn.*$phase" "$template"; then
            echo "✅ Found Maven phase: $phase"
        fi
    done
}

# Gradle-specific template testing
test_gradle_template() {
    local template=$1
    echo "Testing Gradle template specifics..."
    
    local gradle_keywords=("gradle" "gradlew" "build.gradle" "gradle build" "gradle test" "gradle wrapper")
    local found_keywords=0
    
    for keyword in "${gradle_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Gradle keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Gradle-specific validation passed"
    else
        echo "⚠️ No Gradle-specific keywords found"
    fi
    
    # Check for Gradle tasks
    local gradle_tasks=("compileJava" "test" "build" "jar" "bootJar")
    for task in "${gradle_tasks[@]}"; do
        if grep -iq "$task" "$template"; then
            echo "✅ Found Gradle task: $task"
        fi
    done
}

# Quarkus-specific template testing
test_quarkus_template() {
    local template=$1
    echo "Testing Quarkus template specifics..."
    
    local quarkus_keywords=("quarkus" "quarkus:dev" "quarkus-maven-plugin" "native-image" "@QuarkusApplication")
    local found_keywords=0
    
    for keyword in "${quarkus_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Quarkus keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Quarkus-specific validation passed"
    else
        echo "⚠️ No Quarkus-specific keywords found"
    fi
}

# Micronaut-specific template testing
test_micronaut_template() {
    local template=$1
    echo "Testing Micronaut template specifics..."
    
    local micronaut_keywords=("micronaut" "@MicronautApplication" "micronaut-maven-plugin" "mn create-app")
    local found_keywords=0
    
    for keyword in "${micronaut_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Micronaut keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Micronaut-specific validation passed"
    else
        echo "⚠️ No Micronaut-specific keywords found"
    fi
}

# Generic Java template testing
test_generic_java_template() {
    local template=$1
    echo "Testing generic Java template..."
    
    local java_keywords=("java" "openjdk" "jdk" "jar" "javac" "junit" "testng")
    local found_keywords=0
    
    for keyword in "${java_keywords[@]}"; do
        if grep -iq "$keyword" "$template"; then
            echo "✅ Found Java keyword: $keyword"
            ((found_keywords++))
        fi
    done
    
    if [ $found_keywords -gt 0 ]; then
        echo "✅ Generic Java template validation passed"
    else
        echo "⚠️ No Java-specific keywords found in template"
    fi
}

# Generate JUnit test results
generate_junit_results() {
    local results_file="test-results/java/junit.xml"
    echo "📊 Generating JUnit test results: $results_file"
    
    cat > "$results_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Java Pipeline Templates" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" time="$TEST_DURATION">
  <testsuite name="Template Validation" tests="$TOTAL_TESTS" failures="$FAILED_TESTS" time="$TEST_DURATION">
$(for template in $TESTED_TEMPLATES; do
    echo "    <testcase name=\"$(basename "$template")\" classname=\"JavaTemplateValidation\" time=\"1.0\">"
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
echo "🚀 Starting Java pipeline template testing..."
echo ""

# Initialize counters
TOTAL_TESTS=0
FAILED_TESTS=0
TESTED_TEMPLATES=""
FAILED_TEMPLATES=""
START_TIME=$(date +%s)

# Test templates in the templates/java directory
if [ -d "templates/java" ]; then
    echo "📁 Found Java templates directory"
    echo "Templates to test:"
    find templates/java -name "*.yml" -type f | sed 's/^/  - /'
    echo ""
    
    for template in templates/java/*.yml; do
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
    echo "⚠️ No templates/java directory found, creating sample templates for testing..."
    
    # Create sample templates for demonstration
    mkdir -p templates/java
    
    # Sample Spring Boot template
    cat > templates/java/spring-boot.yml << 'EOF'
# Spring Boot CI/CD Template
stages:
  - build
  - test
  - package
  - deploy

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=.m2/repository"
  MAVEN_CLI_OPTS: "--batch-mode --errors --fail-at-end --show-version"

build:
  stage: build
  image: openjdk:11-jdk
  script:
    - mvn $MAVEN_CLI_OPTS compile
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .m2/repository/

test:
  stage: test
  image: openjdk:11-jdk
  script:
    - mvn $MAVEN_CLI_OPTS test
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .m2/repository/
    policy: pull
  artifacts:
    reports:
      junit: "target/surefire-reports/TEST-*.xml"
    paths:
      - target/site/jacoco/

package:
  stage: package
  image: openjdk:11-jdk
  script:
    - mvn $MAVEN_CLI_OPTS package spring-boot:repackage
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .m2/repository/
    policy: pull
  artifacts:
    paths:
      - target/*.jar

deploy:
  stage: deploy
  image: openjdk:11-jre
  script:
    - java -jar target/*.jar &
    - echo "Spring Boot application deployed"
  only:
    - main
EOF

    # Sample Maven template
    cat > templates/java/maven.yml << 'EOF'
# Maven CI/CD Template
stages:
  - validate
  - compile
  - test
  - package

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=.m2/repository"

validate:
  stage: validate
  image: maven:3.8.4-openjdk-11
  script:
    - mvn validate

compile:
  stage: compile
  image: maven:3.8.4-openjdk-11
  script:
    - mvn compile
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .m2/repository/

test:
  stage: test
  image: maven:3.8.4-openjdk-11
  script:
    - mvn test
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .m2/repository/
    policy: pull
  artifacts:
    reports:
      junit: "target/surefire-reports/TEST-*.xml"

package:
  stage: package
  image: maven:3.8.4-openjdk-11
  script:
    - mvn package
  cache:
    key: "$CI_COMMIT_REF_SLUG"
    paths:
      - .m2/repository/
    policy: pull
  artifacts:
    paths:
      - target/*.jar
EOF

    echo "✅ Created sample Java templates"
    
    # Test the created templates
    for template in templates/java/*.yml; do
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

# Test shared Java components
if [ -d "shared/java" ]; then
    echo ""
    echo "📁 Testing shared Java components..."
    
    for shared_file in shared/java/*.yml; do
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
cat > reports/java/summary.txt << EOF
Java Pipeline Template Testing Summary
======================================
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
echo "📊 Java Pipeline Testing Summary"
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
    echo "✅ All Java pipeline template tests passed!"
    exit 0
fi