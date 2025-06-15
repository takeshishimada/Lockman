# Makefile for Lockman Swift Package
.PHONY: install format lint build test clean help

help:
	@echo "Available commands:"
	@echo "  make install     - Install dependencies"
	@echo "  make format      - Format code"
	@echo "  make lint        - Lint code"
	@echo "  make build       - Build package"
	@echo "  make test        - Run tests"
	@echo "  make clean       - Clean artifacts"

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
