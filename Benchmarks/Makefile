# Makefile for Lockman Benchmarks
# Usage: make benchmarks
.PHONY: benchmarks install clean help run quick verify

# Default target
help:
	@echo "Lockman Benchmark Utilities"
	@echo "==========================="
	@echo "Available commands:"
	@echo "  make benchmarks - Full benchmark workflow"
	@echo "  make install    - Install required libraries"
	@echo "  make clean      - Clean benchmark cache"
	@echo ""
	@echo "Individual steps:"
	@echo "  make run        - Run benchmarks only"

# Install required libraries for benchmarks
install:
	@echo "📦 Installing benchmark dependencies..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "❌ Homebrew is required but not installed."; \
		echo "Please install Homebrew: https://brew.sh"; \
		exit 1; \
	fi
	@echo "Installing jemalloc for optimal memory profiling..."
	@brew install jemalloc || echo "jemalloc already installed"
	@echo "✅ Benchmark dependencies installed successfully!"

# Clean benchmark cache and build artifacts
clean:
	@echo "🧹 Cleaning benchmark cache and build artifacts..."
	@if [ -d "Benchmarks" ]; then \
		echo "Cleaning Benchmarks directory..."; \
		cd Benchmarks && swift package clean 2>/dev/null || true; \
		rm -rf .build 2>/dev/null || true; \
		swift package reset 2>/dev/null || true; \
		echo "✅ Benchmark cache cleaned"; \
	else \
		echo "⚠️  Benchmarks directory not found"; \
	fi

# Run benchmarks only (without setup)
run:
	@echo "🏃 Running Lockman benchmarks..."
	@if [ ! -d "Benchmarks" ]; then \
		echo "❌ Benchmarks directory not found."; \
		echo "Please ensure Benchmarks/ directory exists with Package.swift"; \
		exit 1; \
	fi
	@echo "Changing to Benchmarks directory..."
	@cd Benchmarks && \
	echo "Resolving dependencies..." && \
	swift package resolve && \
	echo "Building in release mode..." && \
	swift build -c release && \
	echo "Executing benchmarks..." && \
	swift package benchmark --target LockmanBenchmarks
	@echo "✅ Benchmarks completed successfully!"

# Full benchmark workflow: Install -> Clean -> Run
benchmarks: install clean run
	@echo ""
	@echo "🏆 Complete benchmark workflow finished!"
	@echo "📊 Results shown above include performance metrics for:"
	@echo "   - .run (baseline TCA effect)"
	@echo "   - .withLock SingleExecution strategy"
	@echo "   - .withLock PriorityBased strategy"
	@echo "   - .withLock DynamicCondition strategy"
	@echo "   - .withLock CompositeStrategy"
	@echo ""
	@echo "💡 Use the results to optimize your Lockman integration!"

# Quick benchmark (skip install, clean cache only)
quick: clean run
	@echo "⚡ Quick benchmark completed!"

# Verify benchmark setup
verify:
	@echo "🔍 Verifying benchmark setup..."
	@echo -n "Homebrew: "
	@if command -v brew >/dev/null 2>&1; then \
		echo "✅ Installed"; \
	else \
		echo "❌ Not installed"; \
	fi
	@echo -n "jemalloc: "
	@if brew list jemalloc >/dev/null 2>&1; then \
		echo "✅ Installed"; \
	else \
		echo "❌ Not installed"; \
	fi
	@echo -n "Benchmarks directory: "
	@if [ -d "Benchmarks" ]; then \
		echo "✅ Found"; \
	else \
		echo "❌ Not found"; \
	fi
	@echo -n "Package.swift: "
	@if [ -f "Benchmarks/Package.swift" ]; then \
		echo "✅ Found"; \
	else \
		echo "❌ Not found"; \
	fi
	@echo -n "Swift: "
	@swift --version | head -n1
