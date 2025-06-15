# Makefile for Lockman Swift Package
.PHONY: install format lint build test clean help xcodebuild xcodebuild-raw build-for-library-evolution

# Default values
CONFIG ?= Debug
PLATFORM ?= MACOS
WORKSPACE ?= Lockman.xcworkspace
DERIVED_DATA_PATH ?= .build/derivedData
SCHEME ?= LockmanCore
XCODEBUILD_ARGUMENT ?= test

help:
	@echo "Available commands:"
	@echo "  make install                  - Install dependencies"
	@echo "  make format                   - Format code"
	@echo "  make lint                     - Lint code"
	@echo "  make build                    - Build package"
	@echo "  make test                     - Run tests"
	@echo "  make clean                    - Clean artifacts"
	@echo "  make xcodebuild               - Build/test with xcodebuild"
	@echo "  make build-for-library-evolution - Build for library evolution"

install:
	@echo "📦 Installing dependencies..."
	@brew install swiftlint swiftformat

format:
	@echo "🎨 Formatting Swift code..."
	@swiftformat Sources/ Tests/ Examples/

lint:
	@echo "🔍 Linting Swift code..."
	@swiftlint

build: format lint
	@echo "🔨 Building Swift package..."
	@swift build

test: format lint
	@echo "🧪 Running tests..."
	@swift test

clean:
	@echo "🧹 Cleaning build artifacts..."
	@swift package clean

# Platform-specific destinations
DESTINATION_IOS = platform=iOS Simulator,name=iPhone 15
DESTINATION_MACOS = platform=macOS
DESTINATION_TVOS = platform=tvOS Simulator,name=Apple TV
DESTINATION_WATCHOS = platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)

# Set destination based on platform
ifeq ($(PLATFORM),IOS)
	DESTINATION = $(DESTINATION_IOS)
else ifeq ($(PLATFORM),MACOS)
	DESTINATION = $(DESTINATION_MACOS)
else ifeq ($(PLATFORM),TVOS)
	DESTINATION = $(DESTINATION_TVOS)
else ifeq ($(PLATFORM),WATCHOS)
	DESTINATION = $(DESTINATION_WATCHOS)
endif

xcodebuild:
	@echo "🔨 Running xcodebuild $(XCODEBUILD_ARGUMENT) for $(PLATFORM)..."
	@if command -v xcbeautify >/dev/null 2>&1; then \
		set -o pipefail && \
		xcodebuild $(XCODEBUILD_ARGUMENT) \
			-workspace $(WORKSPACE) \
			-scheme $(SCHEME) \
			-configuration $(CONFIG) \
			-destination "$(DESTINATION)" \
			-derivedDataPath $(DERIVED_DATA_PATH) \
			| xcbeautify; \
	else \
		xcodebuild $(XCODEBUILD_ARGUMENT) \
			-workspace $(WORKSPACE) \
			-scheme $(SCHEME) \
			-configuration $(CONFIG) \
			-destination "$(DESTINATION)" \
			-derivedDataPath $(DERIVED_DATA_PATH); \
	fi

xcodebuild-raw:
	@echo "🔨 Running xcodebuild for $(SCHEME)..."
	@if command -v xcbeautify >/dev/null 2>&1; then \
		set -o pipefail && \
		xcodebuild \
			-workspace $(WORKSPACE) \
			-scheme $(SCHEME) \
			-configuration $(CONFIG) \
			-destination "$(DESTINATION_MACOS)" \
			-derivedDataPath $(DERIVED_DATA_PATH) \
			| xcbeautify; \
	else \
		xcodebuild \
			-workspace $(WORKSPACE) \
			-scheme $(SCHEME) \
			-configuration $(CONFIG) \
			-destination "$(DESTINATION_MACOS)" \
			-derivedDataPath $(DERIVED_DATA_PATH); \
	fi

build-for-library-evolution:
	@echo "📚 Building for library evolution..."
	@if command -v xcbeautify >/dev/null 2>&1; then \
		set -o pipefail && \
		xcodebuild build \
			-workspace $(WORKSPACE) \
			-scheme $(SCHEME) \
			-configuration Release \
			-destination "$(DESTINATION_MACOS)" \
			BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
			| xcbeautify; \
	else \
		xcodebuild build \
			-workspace $(WORKSPACE) \
			-scheme $(SCHEME) \
			-configuration Release \
			-destination "$(DESTINATION_MACOS)" \
			BUILD_LIBRARY_FOR_DISTRIBUTION=YES; \
	fi
