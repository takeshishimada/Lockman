# Configuration
CONFIG = Debug

DERIVED_DATA_PATH = ~/.derivedData/$(CONFIG)

# Platform definitions
PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iPhone)
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,id=$(call udid_for,TV)
PLATFORM_VISIONOS = visionOS Simulator,id=$(call udid_for,Vision)
PLATFORM_WATCHOS = watchOS Simulator,id=$(call udid_for,Watch)

PLATFORM = IOS
DESTINATION = platform="$(PLATFORM_$(PLATFORM))"

PLATFORM_ID = $(shell echo "$(DESTINATION)" | sed -E "s/.+,id=(.+)/\1/")

SCHEME = LockmanCore

WORKSPACE = Lockman.xcworkspace

XCODEBUILD_ARGUMENT = test

XCODEBUILD_FLAGS = \
	-configuration $(CONFIG) \
	-derivedDataPath $(DERIVED_DATA_PATH) \
	-destination $(DESTINATION) \
	-scheme "$(SCHEME)" \
	-skipMacroValidation \
	-skipPackagePluginValidation \
	-workspace $(WORKSPACE)

XCODEBUILD_COMMAND = xcodebuild $(XCODEBUILD_ARGUMENT) $(XCODEBUILD_FLAGS)

# Use xcbeautify if available
ifneq ($(strip $(shell which xcbeautify)),)
	XCODEBUILD = set -o pipefail && $(XCODEBUILD_COMMAND) | xcbeautify
else
	XCODEBUILD = $(XCODEBUILD_COMMAND)
endif

# Legacy commands for compatibility
install:
	@echo "📦 Installing dependencies..."
	@brew install swiftlint swiftformat xcbeautify

format:
	@echo "🎨 Formatting Swift code..."
	@find . \
		-path '*/Documentation.docc' -prune -o \
		-name '*.swift' \
		-not -path '*/.*' -print0 \
		| xargs -0 swiftformat --swiftversion 6.0

lint:
	@echo "🔍 Linting Swift code..."
	@swiftlint

build:
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

help:
	@echo "Available commands:"
	@echo "  make warm-simulator          - Boot simulator for specified platform"
	@echo "  make xcodebuild              - Run xcodebuild with beautified output"
	@echo "  make xcodebuild-raw          - Run xcodebuild with raw output"
	@echo "  make build-for-library-evolution - Build for library evolution"
	@echo "  make format                  - Format code"
	@echo "  make lint                    - Lint code"
	@echo "  make build                   - Build package"
	@echo "  make test                    - Run tests"
	@echo "  make clean                   - Clean artifacts"
	@echo ""
	@echo "Platform options:"
	@echo "  PLATFORM=IOS                 - iOS Simulator (default)"
	@echo "  PLATFORM=MACOS               - macOS"
	@echo "  PLATFORM=MAC_CATALYST        - Mac Catalyst"
	@echo "  PLATFORM=TVOS                - tvOS Simulator"
	@echo "  PLATFORM=VISIONOS            - visionOS Simulator"
	@echo "  PLATFORM=WATCHOS             - watchOS Simulator"
	@echo ""
	@echo "Examples:"
	@echo "  make xcodebuild PLATFORM=MACOS"
	@echo "  make xcodebuild XCODEBUILD_ARGUMENT=build"

# TCA-style commands
warm-simulator:
	@test "$(PLATFORM_ID)" != "" \
		&& xcrun simctl boot $(PLATFORM_ID) \
		&& open -a Simulator --args -CurrentDeviceUDID $(PLATFORM_ID) \
		|| exit 0

xcodebuild: warm-simulator
	$(XCODEBUILD)

xcodebuild-raw: warm-simulator
	$(XCODEBUILD_COMMAND)

build-for-library-evolution:
	@echo "📚 Building for library evolution..."
	@swift build \
		-q \
		-c release \
		--target LockmanCore \
		-Xswiftc -emit-module-interface \
		-Xswiftc -enable-library-evolution

.PHONY: build build-for-library-evolution clean format help install lint test warm-simulator xcodebuild xcodebuild-raw

# Function to get UDID for simulator
define udid_for
$(shell xcrun simctl list --json devices available '$(1)' | jq -r '[.devices|to_entries|sort_by(.key)|reverse|.[].value|select(length > 0)|.[0]][0].udid')
endef