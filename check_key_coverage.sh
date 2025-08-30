#!/bin/bash

# Check coverage for key files
key_tests=(
    "LockmanPriorityBasedStrategyTests"
    "LockmanConcurrencyLimitedStrategyTests"
    "LockmanGroupCoordinationStrategyTests"
    "LockmanCompositeStrategyTests"
    "EffectLockmanTests"
)

echo "Checking coverage for key test files..."
echo "====================================="

for test in "${key_tests[@]}"; do
    echo "Testing: $test"
    
    # Clean previous results
    rm -rf ./DerivedData/Logs/Test/*.xcresult 2>/dev/null
    
    # Run test
    xcodebuild test -configuration Debug -scheme "Lockman" \
        -destination "platform=macOS,name=My Mac" \
        -workspace .github/package.xcworkspace \
        -skipMacroValidation \
        -only-testing:LockmanTestsNew/$test \
        -enableCodeCoverage YES \
        -derivedDataPath ./DerivedData \
        -quiet 2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Extract coverage for relevant strategy files
        xcrun xccov view --report "$(find ./DerivedData/Logs/Test -name "*.xcresult" -type d | head -1)" --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Overall: {data[\"lineCoverage\"]:.2%}')

# Strategy-specific coverage
strategy_keywords = ['Priority', 'Concurrency', 'Group', 'Composite', 'Effect']
for target in data.get('targets', []):
    for file in target.get('files', []):
        filename = file['name']
        if any(keyword in filename for keyword in strategy_keywords):
            if file.get('lineCoverage', 0) > 0.1:  # Only show files with >10% coverage
                coverage = file['lineCoverage']
                print(f'  {filename}: {coverage:.2%} ({file[\"coveredLines\"]}/{file[\"executableLines\"]})')
"
    else
        echo "  ❌ Test failed"
    fi
    echo ""
done