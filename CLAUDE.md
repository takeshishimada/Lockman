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
- Apply appropriate labels based on the type of change and affected modules
- Assign yourself as the assignee
- Direct commits to main and develop branches are prohibited - all changes must be made through Pull Requests

### PR Title Format
PR titles should follow the semantic commit format:
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `style:` Code style changes (formatting, missing semicolons, etc.)
- `refactor:` Code refactoring
- `perf:` Performance improvements
- `test:` Test additions or updates
- `chore:` Maintenance tasks (updating dependencies, etc.)
- `ci:` CI/CD configuration changes

### Required Labels
Every PR must have at least one label from each applicable category:

1. **Change Type** (required):
   - `enhancement`: New features or improvements
   - `bug`: Bug fixes
   - `documentation`: Documentation updates
   - `refactor`: Code refactoring
   - `test`: Test-related changes
   - `performance`: Performance optimizations
   - `breaking change`: Changes that break backward compatibility

2. **Module** (if applicable):
   - `core`: Changes to LockmanCore module
   - `composable`: Changes to LockmanComposable module
   - `macro`: Changes to macro implementations

3. **Additional Labels** (optional):
   - `good first issue`: Suitable for newcomers
   - `help wanted`: Requesting additional help
   - `question`: Needs clarification
   - `duplicate`: Duplicate of existing issue/PR
   - `invalid`: Invalid issue/PR
   - `wontfix`: Will not be addressed


## Testing
Use the following commands to run tests:
```bash
make XCODEBUILD_ARGUMENT="test" CONFIG=Debug PLATFORM="IOS" WORKSPACE=.github/package.xcworkspace xcodebuild
make XCODEBUILD_ARGUMENT="test" CONFIG=Debug PLATFORM="MACOS" WORKSPACE=.github/package.xcworkspace xcodebuild
```