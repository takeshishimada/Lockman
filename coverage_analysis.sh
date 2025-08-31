#!/bin/bash

# Coverage analysis script for all unit test files
# This script runs each test file individually and extracts coverage information

echo "Starting comprehensive coverage analysis..."
echo "=================================="

# List of all test files (class names)
test_files=(
    "LockmanManagerTests"
    "LockmanResultTests"
    "LockmanUnlockTests"
    "LockmanUnlockOptionTests"
    "LockmanCancellationErrorTests"
    "LockmanRegistrationErrorTests"
    "LockmanStrategyErrorTests"
    "LockmanSingleExecutionStrategyTests"
    "LockmanPriorityBasedStrategyTests"
    "LockmanConcurrencyLimitedStrategyTests"
    "LockmanGroupCoordinationStrategyTests"
    "LockmanCompositeStrategyTests"
    "LockmanLoggerTests"
    "ManagedCriticalStateTests"
    "LoggerTests"
    "LockmanActionIdTests"
    "LockmanBoundaryIdTests"
    "LockmanStrategyIdTests"
    "LockmanGroupIdTests"
    "LockmanStrategyTests"
    "LockmanPrecedingCancellationErrorTests"
    "LockmanIssueReporterTests"
    "LockmanInfoTests"
    "LockmanActionTests"
    "LockmanErrorTests"
    "AnyLockmanBoundaryIdTests"
    "AnyLockmanStrategyTests"
    "AnyLockmanGroupIdTests"
    "EffectLockmanTests"
    "EffectLockmanInternalTests"
    "ReducerLockmanTests"
    "LockmanReducerTests"
    "LockmanDynamicConditionReducerTests"
    "LockmanComposableMacrosTests"
    "LockmanComposableIssueReporterTests"
)

# Additional strategy component tests
strategy_tests=(
    "LockmanSingleExecutionActionTests"
    "LockmanSingleExecutionInfoTests"
    "LockmanSingleExecutionErrorTests"
    "LockmanCompositeActionTests"
    "LockmanCompositeInfoTests"
    "LockmanPriorityBasedInfoTests"
    "LockmanPriorityBasedErrorTests"
    "LockmanPriorityBasedActionTests"
    "LockmanStrategyContainerTests"
    "LockmanStateTests"
    "LockmanGroupCoordinatedActionTests"
    "LockmanGroupCoordinationErrorTests"
    "LockmanGroupCoordinationRoleTests"
    "LockmanGroupCoordinatedInfoTests"
    "LockmanConcurrencyGroupTests"
    "LockmanConcurrencyLimitTests"
    "LockmanConcurrencyLimitedActionTests"
    "LockmanConcurrencyLimitedErrorTests"
    "LockmanConcurrencyLimitedInfoTests"
    "LockmanDebugFormattersTests"
    "LockmanDebugTests"
)

# Combine all test arrays
all_tests=("${test_files[@]}" "${strategy_tests[@]}")

# Results tracking
declare -A coverage_results
failed_tests=()
zero_coverage_tests=()

# Function to run a single test and get coverage
run_test_with_coverage() {
    local test_name=$1
    echo "Running test: $test_name"
    echo "----------------------------------------"
    
    # Clean up previous results
    rm -rf ./DerivedData/Logs/Test/*.xcresult 2>/dev/null
    
    # Run the test with coverage
    xcodebuild test -configuration Debug -scheme "Lockman" \
        -destination "platform=macOS,name=My Mac" \
        -workspace .github/package.xcworkspace \
        -skipMacroValidation \
        -only-testing:LockmanTestsNew/$test_name \
        -enableCodeCoverage YES \
        -derivedDataPath ./DerivedData \
        -quiet 2>/dev/null
    
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "❌ Test failed: $test_name"
        failed_tests+=("$test_name")
        coverage_results["$test_name"]="FAILED"
        return 1
    fi
    
    # Find the latest xcresult file
    local xcresult_file=$(find ./DerivedData/Logs/Test -name "*.xcresult" -type d | head -1)
    
    if [ -z "$xcresult_file" ]; then
        echo "❌ No xcresult file found for $test_name"
        failed_tests+=("$test_name")
        coverage_results["$test_name"]="NO_RESULT"
        return 1
    fi
    
    # Extract coverage summary
    local coverage_json=$(xcrun xccov view --report "$xcresult_file" --json 2>/dev/null)
    
    if [ -z "$coverage_json" ]; then
        echo "❌ Could not extract coverage for $test_name"
        failed_tests+=("$test_name")
        coverage_results["$test_name"]="NO_COVERAGE"
        return 1
    fi
    
    # Parse overall coverage percentage
    local line_coverage=$(echo "$coverage_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    coverage = data.get('lineCoverage', 0)
    print(f'{coverage:.2%}')
except:
    print('0.00%')
")
    
    coverage_results["$test_name"]="$line_coverage"
    
    if [[ "$line_coverage" == "0.00%" ]]; then
        zero_coverage_tests+=("$test_name")
        echo "⚠️  Zero coverage: $test_name"
    else
        echo "✅ Coverage: $test_name - $line_coverage"
    fi
    
    echo ""
}

# Main execution
echo "Found ${#all_tests[@]} test files to analyze"
echo ""

for test in "${all_tests[@]}"; do
    run_test_with_coverage "$test"
done

# Generate summary report
echo "========================================"
echo "COVERAGE ANALYSIS SUMMARY"
echo "========================================"
echo ""

echo "Test Results by Coverage:"
echo "------------------------"

# Sort results by coverage percentage
echo "HIGH COVERAGE (>80%):"
for test in "${all_tests[@]}"; do
    result="${coverage_results[$test]}"
    if [[ "$result" =~ ^[0-9]+\.[0-9]+%$ ]]; then
        # Extract numeric value for comparison
        numeric=$(echo "$result" | sed 's/%//')
        if (( $(echo "$numeric >= 80" | bc -l) )); then
            echo "  ✅ $test: $result"
        fi
    fi
done

echo ""
echo "MEDIUM COVERAGE (20-79%):"
for test in "${all_tests[@]}"; do
    result="${coverage_results[$test]}"
    if [[ "$result" =~ ^[0-9]+\.[0-9]+%$ ]]; then
        numeric=$(echo "$result" | sed 's/%//')
        if (( $(echo "$numeric >= 20 && $numeric < 80" | bc -l) )); then
            echo "  ⚠️  $test: $result"
        fi
    fi
done

echo ""
echo "LOW/ZERO COVERAGE (<20%):"
for test in "${all_tests[@]}"; do
    result="${coverage_results[$test]}"
    if [[ "$result" =~ ^[0-9]+\.[0-9]+%$ ]]; then
        numeric=$(echo "$result" | sed 's/%//')
        if (( $(echo "$numeric < 20" | bc -l) )); then
            echo "  ❌ $test: $result"
        fi
    elif [[ "$result" == "FAILED" || "$result" == "NO_RESULT" || "$result" == "NO_COVERAGE" ]]; then
        echo "  ❌ $test: $result"
    fi
done

echo ""
echo "SUMMARY STATISTICS:"
echo "  Total tests: ${#all_tests[@]}"
echo "  Failed tests: ${#failed_tests[@]}"
echo "  Zero coverage: ${#zero_coverage_tests[@]}"

if [ ${#failed_tests[@]} -gt 0 ]; then
    echo ""
    echo "FAILED TESTS:"
    printf '  %s\n' "${failed_tests[@]}"
fi

if [ ${#zero_coverage_tests[@]} -gt 0 ]; then
    echo ""
    echo "ZERO COVERAGE TESTS (Need Implementation):"
    printf '  %s\n' "${zero_coverage_tests[@]}"
fi

echo ""
echo "Coverage analysis complete!"