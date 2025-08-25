# CLAUDE.md

## Session Start Analysis
When starting a new session for Lockman development, you MUST first analyze the core source files in the Sources directory:
1. Read and understand the main implementation files in Sources/Lockman/
2. Pay special attention to protocol definitions, public APIs, and core functionality
3. This ensures consistency with existing code patterns and architecture

## Purpose
Develop a library to implement exclusive control of user actions in application development using TCA

## Current Work Items
All v1.0 roadmap features have been completed

## Test Strategy and Design
For comprehensive test strategy and design documentation, see:
- **[claude_wip.md](claude_wip.md)** - Detailed test strategy design, decision rationale, and implementation planning
- **[Tests/README.md](Tests/README.md)** - Practical test execution guide and developer reference

## Current Issues and Improvements

### Active Issues (tracked in GitHub Issues)
- 🐛 **[Action-Level Lock Method Crash](https://github.com/takeshishimada/Lockman/issues/211)** - `LockmanDynamicConditionReducer` crash due to circular reference
- 🔧 **[Type Safety Enhancement](https://github.com/takeshishimada/Lockman/issues/212)** - Improve Strategy-Info relationship type safety
- 🧹 **[Remove Unused makeCompositeStrategy](https://github.com/takeshishimada/Lockman/issues/213)** - Clean up unused API methods

### Resolved Issues
- ✅ **[LockmanIssueReporter Protocol Integration](https://github.com/takeshishimada/Lockman/issues/209)** - DI architecture implemented
- ✅ **[LockmanSingleExecutionInfo StrategyId Design](https://github.com/takeshishimada/Lockman/issues/210)** - Test strategyId inconsistencies fixed

## Development Guidelines
- Swift versions: 6.0, 5.10, 5.9
- Type-safe implementation
- Single unified Lockman module, developed exclusively for TCA
- Based on Composable Architecture 1.21.0
- When modifying Package.swift, you MUST also update Package@swift-6.0 to keep them in sync

## Communication Guidelines
- **Always be honest about capabilities**: If you cannot do something, clearly state this limitation
- **Do not pretend or simulate**: Never claim to have done something you cannot actually do
- **Clarify when using internal tools**: When using analysis tools or performing research, be clear about what you're actually doing

## Documentation
- Documentation is provided through SwiftDoc comments in source code and DocC documentation
- When modifying source code, you MUST update the corresponding documentation in the same commit
- README updates are done at release time or when manually determined necessary

## Code Formatting
- Run `make format` before committing changes to ensure consistent code style
- This command uses swift-format to format all Swift files in the project
- Code formatting is required for all PRs
- **IMPORTANT**: Always run `make format` before creating any commit
- The formatter may modify multiple files automatically - review and include these changes in your commit

## Code Editing Guidelines
- When updating repetitive patterns (e.g., adding missing parameter documentation), use `replace_all=true` in Edit operations
- For safety, use `Grep` tool first to verify the number of occurrences before using `replace_all=true`
- Prefer `MultiEdit` with specific context for critical changes

## Commit Workflow
1. Make your code changes
2. Run `make format` to format all Swift files
3. Review the formatting changes and stage all modified files
4. Run tests using `xcodebuild test -configuration Debug -scheme "Lockman" -destination "platform=macOS,name=My Mac" -workspace .github/package.xcworkspace -skipMacroValidation` for macOS or `make xcodebuild` for iOS
5. Fix any test failures before proceeding
6. Create your commit with a semantic commit message
7. Push to your feature branch

## Pull Request

### Development Workflow Requirements
- **ALL changes must be made through Pull Requests** - No exceptions
- Direct commits to main branch are strictly prohibited
- This ensures:
  - All changes are properly reviewed
  - CI/CD tests run on all changes
  - Release notes are automatically generated with complete change history
  - Consistent development practices across all contributors

### Pre-PR Checklist
1. **Run Tests**: Execute tests ONLY if Swift code has been modified. For documentation-only changes, skip testing
2. **Fix All Test Failures**: All tests must pass before creating a PR (when tests are run)
3. **No Test Coverage Requirements**: Test coverage is not enforced
4. **Verify Build**: Ensure the project builds without errors (only for code changes)

### PR Requirements
- Commit messages must follow Semantic Commit Message rules
- Apply appropriate labels based on the type of change and affected modules
- Assign yourself as the assignee
- Direct commits to main branch are prohibited - all changes must be made through Pull Requests
- After PR is merged, delete the feature branch

### Git Branch Protection Rules
- NEVER execute the following commands on main branch:
  - `git commit`
  - `git cherry-pick`
  - `git merge` (except from PR)
  - `git rebase`
- When requested to cherry-pick, merge, or rebase:
  1. First check the current branch with `git branch --show-current`
  2. If on main, create a new feature branch first
  3. Perform the operation on the feature branch
  4. Create a Pull Request for review

### PR Creation Command
When creating a PR, use the following command format:
```bash
gh pr create \
  --title "type: description" \
  --assignee @me \
  --label "label1,label2" \
  --body "PR body content"
```
- Always include `--assignee @me` to assign yourself
- The `--title` should follow the semantic commit format
- The `--body` should include Summary and Changes sections
- Use `--label` to add appropriate labels based on the mappings below

### Automatic Label Mapping
Apply labels based on the PR title prefix:

**Change Type Labels (required):**
- `feat:` → `enhancement`
- `fix:` → `bug`
- `docs:` → `documentation`
- `refactor:` → `refactor`
- `test:` → `test`
- `perf:` → `performance`
- `chore:` → `enhancement`
- `ci:` → `enhancement`
- `breaking:` or `!:` → `breaking change`

**Module Labels (add if changes affect specific modules):**
- Changes in `Sources/Lockman/` → `core`
- Changes in `Sources/LockmanMacros/` → `macro`

**Example Commands:**
```bash
# Documentation change
gh pr create \
  --title "docs: update README" \
  --assignee @me \
  --label "documentation" \
  --body "..."

# Feature affecting Lockman
gh pr create \
  --title "feat: add new locking strategy" \
  --assignee @me \
  --label "enhancement,core" \
  --body "..."

# Refactoring with breaking changes
gh pr create \
  --title "refactor!: restructure API" \
  --assignee @me \
  --label "refactor,breaking change" \
  --body "..."
```

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
   - `core`: Changes to Lockman module
   - `macro`: Changes to macro implementations

3. **Additional Labels** (optional):
   - `good first issue`: Suitable for newcomers
   - `help wanted`: Requesting additional help
   - `question`: Needs clarification
   - `duplicate`: Duplicate of existing issue/PR
   - `invalid`: Invalid issue/PR
   - `wontfix`: Will not be addressed


## Testing

### Local Testing Requirements
- Local testing is required on macOS and iOS only
- All Swift versions (6.0, 5.10, 5.9) are tested in CI/CD environment
- Use your local Xcode environment for testing before creating a PR

### Testing Commands

**For macOS (Recommended - no simulator needed):**
```bash
xcodebuild test -configuration Debug -scheme "Lockman" -destination "platform=macOS,name=My Mac" -workspace .github/package.xcworkspace -skipMacroValidation
```

**For iOS using Makefile:**
```bash
# Run tests for iOS (automatically finds simulator)
make xcodebuild

# Run tests with raw output (without xcbeautify)
make xcodebuild-raw
```

Note: The Makefile has a known issue with macOS destination specification. Use the direct xcodebuild command for macOS testing.

### Alternative Testing Methods

**iOS tests with specific simulator:**
```bash
# First, list available simulators:
xcrun simctl list devices available | grep iPhone

# Then use a specific simulator (example with iPhone 16):
xcodebuild test -configuration Debug -scheme "Lockman" -destination "platform=iOS Simulator,name=iPhone 16" -workspace .github/package.xcworkspace -skipMacroValidation
```

## Building Examples
When building example projects, use the following flags to skip macro validation:
```bash
# Skip macro validation for Strategies example
xcodebuild build -scheme Strategies -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" -workspace Examples/Strategies/Strategies.xcodeproj/project.xcworkspace -skipMacroValidation
```

Note: The `-skipMacroValidation` flag prevents build failures due to macro approval requirements when building from command line.

## Makefile Commands

The project includes a Makefile with the following commands:

- `make xcodebuild` - Run tests with formatted output (default: iOS)
- `make xcodebuild-raw` - Run tests with raw xcodebuild output
- `make format` - Format all Swift files using swift-format
- `make build-for-library-evolution` - Build release with library evolution support (available locally, removed from CI)
- `make warm-simulator` - Boot and open iOS simulator

### Platform Options
You can specify the platform using the PLATFORM variable:
- `make PLATFORM=IOS` (default)
- `make PLATFORM=MACOS`
- `make PLATFORM=MAC_CATALYST` (available locally, not in CI)
- `make PLATFORM=TVOS` (available locally, not in CI)
- `make PLATFORM=VISIONOS` (available locally, not in CI)
- `make PLATFORM=WATCHOS` (available locally, not in CI)

**Note**: CI testing has been streamlined to focus on iOS and macOS only. Other platforms can still be tested locally using the Makefile.

### Configuration Options
- `make CONFIG=Debug` (default)
- `make CONFIG=Release`

## Release Process

### Pre-Release Checklist
1. **Ensure main branch is clean**: All PRs should be merged and CI passing
2. **Run full test suite**: Execute tests on all supported platforms
3. **Review changes**: Confirm changes to be included in the release

### Release Steps
1. **Create Release PR**
   ```bash
   git checkout -b release/1.x.x
   # Update the following in README.md:
   # - Installation section: Update from: "1.x.x" to new version
   # - Version Compatibility table: Add new version, move old patch versions to Other versions
   # - Documentation section: No update needed for patch version changes only
   git add -A
   git commit -m "chore: prepare for 1.x.x release"
   gh pr create --title "chore: prepare for 1.x.x release" --body "Prepare for version 1.x.x release"
   ```

2. **After PR is merged, create and push tag**
   ```bash
   git checkout main
   git pull origin main
   git tag -a 1.x.x -m "Release version 1.x.x"
   git push origin 1.x.x
   ```

3. **Create GitHub Release**
   - Go to GitHub Releases page
   - Click "Create a new release"
   - Select the tag you just created
   - Title: "1.x.x"
   - Generate release notes from previous tag
   - Review and edit the auto-generated notes
   - Publish release

### Release Notes Template
```
## What's Changed
- Feature: Description of new features
- Fix: Description of bug fixes
- Improvement: Description of improvements

## Full Changelog
https://github.com/takeshishimada/Lockman/compare/1.x.x...1.x.x
```
