# Claude.md

## Purpose
Develop a library to implement exclusive control of user actions in application development using TCA

## Development Guidelines
- Swift versions: 6.0, 5.10, 5.9
- Type-safe implementation
- Test-driven development
- Modules are divided into LockmanComposable and LockmanCore, but developed exclusively for TCA
- Based on Composable Architecture 1.17
- When modifying Package.swift, also update Package@swift-6.0

## Documentation
- Documentation is provided through SwiftDoc comments in source code and DocC documentation
- Update documentation when changing source code

## Pull Request
- Commit messages must follow Semantic Commit Message rules
- Apply appropriate labels
- Assign yourself as the assignee
- Direct commits to main and develop branches are prohibited - all changes must be made through Pull Requests

## Label Guidelines
In addition to GitHub standard labels, use the following custom labels:

### Change Types
- breaking change: Backward-incompatible changes
- performance: Performance improvements
- refactor: Code refactoring
- test: Test additions/modifications

### Module-Specific
- core: LockmanCore module related
- composable: LockmanComposable module related
- macro: Macro implementation related

## Testing
Use the following commands to run tests:
```bash
make XCODEBUILD_ARGUMENT="test" CONFIG=Debug PLATFORM="IOS" WORKSPACE=.github/package.xcworkspace xcodebuild
make XCODEBUILD_ARGUMENT="test" CONFIG=Debug PLATFORM="MACOS" WORKSPACE=.github/package.xcworkspace xcodebuild
```