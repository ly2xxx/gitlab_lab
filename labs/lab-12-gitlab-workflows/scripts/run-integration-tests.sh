#!/bin/bash
# run-integration-tests.sh
# Integration test script that may occasionally fail to demonstrate retry patterns

set -e

echo "🧪 Starting integration test suite"
echo "🔄 This test may occasionally fail to demonstrate retry mechanisms"

# Simulate flaky behavior - fail randomly 30% of the time
RANDOM_NUM=$(( RANDOM % 10 ))
SHOULD_FAIL_RANDOMLY=$((RANDOM_NUM < 3))

echo "🎲 Random factor: $RANDOM_NUM (fail if < 3)"

# Test configuration
TESTS_TO_RUN=(
    "api_connectivity"
    "database_connection"
    "external_service_integration"
    "message_queue_processing"
    "file_storage_access"
    "authentication_flow"
    "data_synchronization"
)

FAILED_TESTS=()
PASSED_TESTS=()

# Function to run individual test
run_test() {
    local test_name=$1
    local test_duration=$(( (RANDOM % 3) + 1 ))
    
    echo "▶️ Running test: $test_name"
    sleep $test_duration
    
    # Simulate test logic with occasional failures
    if [ $SHOULD_FAIL_RANDOMLY -eq 1 ] && [ "$test_name" == "external_service_integration" ]; then
        echo "❌ Test failed: $test_name (simulated network timeout)"
        FAILED_TESTS+=("$test_name")
        return 1
    elif [ $SHOULD_FAIL_RANDOMLY -eq 1 ] && [ "$test_name" == "message_queue_processing" ]; then
        echo "❌ Test failed: $test_name (simulated queue overload)"
        FAILED_TESTS+=("$test_name")
        return 1
    else
        echo "✅ Test passed: $test_name"
        PASSED_TESTS+=("$test_name")
        return 0
    fi
}

# Main test execution
echo "📋 Running ${#TESTS_TO_RUN[@]} integration tests..."

START_TIME=$(date +%s)

for test in "${TESTS_TO_RUN[@]}"; do
    if ! run_test "$test"; then
        echo "⚠️ Test failure detected, continuing with remaining tests..."
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Generate test report
echo ""
echo "📊 Integration Test Report"
echo "=========================="
echo "Total tests: ${#TESTS_TO_RUN[@]}"
echo "Passed: ${#PASSED_TESTS[@]}"
echo "Failed: ${#FAILED_TESTS[@]}"
echo "Duration: ${DURATION}s"
echo ""

if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
    echo "✅ Passed tests:"
    for test in "${PASSED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo ""
fi

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo "❌ Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo ""
    echo "💡 These failures are simulated to demonstrate retry mechanisms"
    echo "🔄 The job will be retried automatically if configured"
    exit 1
fi

echo "🎉 All integration tests passed!"
echo "✨ Integration test suite completed successfully"