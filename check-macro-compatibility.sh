#!/bin/bash

# Swift Macro Compatibility Check Script
# This script tests the package against different swift-syntax versions

set -e

VERBOSE=${1:-false}
SWIFT_SYNTAX_VERSIONS=(
    "509.0.0"
    "510.0.0"
    "600.0.0"
    "601.0.1"
)

echo "🔍 Starting Swift Macro Compatibility Check"
echo "============================================"

for VERSION in "${SWIFT_SYNTAX_VERSIONS[@]}"; do
    echo ""
    echo "📦 Testing with swift-syntax $VERSION"
    echo "--------------------------------------------"
    
    # Create a temporary directory for this version
    TEMP_DIR=$(mktemp -d)
    cp -R . "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Update Package.swift to use specific swift-syntax version
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|\"509.0.0\" ..< \"602.0.0\"|exact: \"$VERSION\"|" Package.swift
        sed -i '' "s|\"509.0.0\" ..< \"602.0.0\"|exact: \"$VERSION\"|" Package@swift-6.0.swift 2>/dev/null || true
    else
        sed -i "s|\"509.0.0\" ..< \"602.0.0\"|exact: \"$VERSION\"|" Package.swift
        sed -i "s|\"509.0.0\" ..< \"602.0.0\"|exact: \"$VERSION\"|" Package@swift-6.0.swift 2>/dev/null || true
    fi
    
    # Clean and reset
    rm -rf .build Package.resolved
    
    echo "🔧 Resolving dependencies..."
    if [ "$VERBOSE" = "true" ]; then
        swift package resolve
    else
        swift package resolve > /dev/null 2>&1
    fi
    
    echo "🏗️  Building package..."
    if [ "$VERBOSE" = "true" ]; then
        swift build
    else
        if ! swift build > build_output.txt 2>&1; then
            echo "❌ Build failed with swift-syntax $VERSION"
            echo "Error output:"
            cat build_output.txt
            cd - > /dev/null
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    fi
    
    echo "✅ Compatible with swift-syntax $VERSION"
    
    # Return to original directory and cleanup
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
done

echo ""
echo "🎉 All compatibility checks passed!"