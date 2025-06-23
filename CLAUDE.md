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

## Code Formatting
- Run `make format` before committing changes to ensure consistent code style
- This command uses swift-format to format all Swift files in the project
- Code formatting is required for all PRs

## Pull Request
- Commit messages must follow Semantic Commit Message rules
- Apply appropriate labels based on the type of change and affected modules
- Assign yourself as the assignee
- Direct commits to main and develop branches are prohibited - all changes must be made through Pull Requests

### Git Branch Protection Rules
- NEVER execute the following commands on main or develop branches:
  - `git commit`
  - `git cherry-pick`
  - `git merge` (except from PR)
  - `git rebase`
- When requested to cherry-pick, merge, or rebase:
  1. First check the current branch with `git branch --show-current`
  2. If on main or develop, create a new feature branch first
  3. Perform the operation on the feature branch
  4. Create a Pull Request for review
- Always work on feature branches (e.g., feat/xxx, fix/xxx, refactor/xxx)

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
- The `--body` should include Summary, Changes, and Test plan sections
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
- Changes in `Sources/LockmanCore/` → `core`
- Changes in `Sources/LockmanComposable/` → `composable`
- Changes in `Sources/LockmanMacros/` → `macro`

**Example Commands:**
```bash
# Documentation change
gh pr create \
  --title "docs: update README" \
  --assignee @me \
  --label "documentation" \
  --body "..."

# Feature affecting LockmanCore
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
# iOS tests
xcodebuild test -configuration Debug -scheme "Lockman-Package" -destination "platform=iOS Simulator,name=iPhone 16" -workspace .github/package.xcworkspace

# macOS tests  
xcodebuild test -configuration Debug -scheme "Lockman-Package" -destination "platform=macOS" -workspace .github/package.xcworkspace
```

## Building Examples
When building example projects, use the following flags to skip macro validation:
```bash
# Skip macro validation for Strategies example
xcodebuild build -scheme Strategies -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" -skipMacroValidation

# Skip macro validation for GitHubClient example  
xcodebuild build -scheme GitHubClient -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" -skipMacroValidation
```

Note: The `-skipMacroValidation` flag prevents build failures due to macro approval requirements when building from command line.