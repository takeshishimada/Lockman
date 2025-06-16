# Makefile for Lockman Swift Package
.PHONY: install format lint build test clean help xcodebuild xcodebuild-raw build-for-library-evolution

# Configuration
XCODE_VERSION ?= 15.4
PLATFORM ?= iOS
CONFIG = Release
WORKSPACE = Lockman.xcworkspace
SCHEME = LockmanCore
PROJECT ?= 
DERIVED_DATA_PATH = .build/DerivedData

# Set destination based on platform
ifeq ($(PLATFORM),iOS)
	DESTINATION = platform=iOS Simulator,name=iPhone 15 Pro,OS=latest
else ifeq ($(PLATFORM),macOS)
	DESTINATION = platform=macOS
else ifeq ($(PLATFORM),tvOS)
	DESTINATION = platform=tvOS Simulator,name=Apple TV,OS=latest
else ifeq ($(PLATFORM),watchOS)
	DESTINATION = platform=watchOS Simulator,name=Apple Watch Series 9 (45mm),OS=latest
else
	DESTINATION = platform=iOS Simulator,name=iPhone 15 Pro,OS=latest
endif

help:
	@echo "Available commands:"
	@echo "  make install                 - Install dependencies"
	@echo "  make format                  - Format code"
	@echo "  make lint                    - Lint code"
	@echo "  make build                   - Build package"
	@echo "  make test                    - Run tests"
	@echo "  make clean                   - Clean artifacts"
	@echo "  make xcodebuild              - Run xcodebuild with beautified output"
	@echo "  make xcodebuild-raw          - Run xcodebuild with raw output"
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
	@rm -rf $(DERIVED_DATA_PATH)
	@rm -rf Package.resolved

xcodebuild:
	@echo "🔨 Running xcodebuild $(XCODEBUILD_ARGUMENT) for $(PLATFORM)..."
	@rm -rf Package.resolved
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
	@echo "🔨 Running xcodebuild $(XCODEBUILD_ARGUMENT) for $(PLATFORM) (raw output)..."
	@rm -rf Package.resolved
	@if [ -n "$(PROJECT)" ]; then \
		xcodebuild $(XCODEBUILD_ARGUMENT) \
			-project $(PROJECT) \
			-scheme "$(SCHEME)" \
			-configuration $(CONFIG) \
			-destination "$(DESTINATION)" \
			-derivedDataPath $(DERIVED_DATA_PATH); \
	else \
		xcodebuild $(XCODEBUILD_ARGUMENT) \
			-workspace $(WORKSPACE) \
			-scheme $(SCHEME) \
			-configuration $(CONFIG) \
			-destination "$(DESTINATION)" \
			-derivedDataPath $(DERIVED_DATA_PATH); \
	fi

build-for-library-evolution:
	@echo "📚 Building for library evolution..."
	@rm -rf Package.resolved
	@swift build \
		-c release \
		--target LockmanCore \
		-Xswiftc -emit-module-interface \
		-Xswiftc -enable-library-evolution
