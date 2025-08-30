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
- **Always use deep analysis (ultrathink)**: Before proposing any implementation, design decision, or architectural change, you MUST carefully consider all implications, edge cases, type safety concerns, architectural consistency, and potential issues. Avoid superficial analysis that could lead to flawed designs or implementations.
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
4. Run tests using `xcodebuild test` or `make xcodebuild` for CI/CD compatibility (use `swift test` for faster local iteration)
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
1. **Run Tests**: Execute `xcodebuild test` or `make xcodebuild` ONLY if Swift code has been modified. For documentation-only changes, skip testing. Use `xcodebuild` to ensure CI/CD compatibility across all Swift versions.
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

**ALWAYS Use xcodebuild for Testing (Required):**
```bash
# For macOS (no simulator needed) - MANDATORY for accurate coverage
xcodebuild test -configuration Debug -scheme "Lockman" -destination "platform=macOS,name=My Mac" -workspace .github/package.xcworkspace -skipMacroValidation

# For iOS using Makefile - supports all Swift versions
make xcodebuild

# Run tests with raw output (without xcbeautify)
make xcodebuild-raw

# For specific test class (with coverage)
xcodebuild test -configuration Debug -scheme "Lockman" -destination "platform=macOS,name=My Mac" -workspace .github/package.xcworkspace -skipMacroValidation -only-testing:LockmanTestsNew/TestClassName

# With coverage enabled for analysis
xcodebuild test -configuration Debug -scheme "Lockman" -destination "platform=macOS,name=My Mac" -workspace .github/package.xcworkspace -skipMacroValidation -enableCodeCoverage YES -derivedDataPath ./DerivedData
```

**swift test (Optional - for quick iteration only):**
```bash
# ONLY for quick development iteration - NOT for coverage analysis
swift test --filter TestClassName
```

**CRITICAL Requirements:**
- **ALWAYS use xcodebuild test for coverage analysis** - swift test does not provide accurate coverage data
- **ALWAYS use xcodebuild test for CI/CD compatibility** - ensures compatibility with Swift 5.9, 5.10, 6.0
- **ALWAYS use xcodebuild test for Pull Request preparation** - matches CI/CD environment exactly
- **swift test is ONLY for quick development iteration** - never rely on it for coverage or production validation

### Alternative Testing Methods

**iOS tests with specific simulator (using xcodebuild):**
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

## TestStore Usage for Effect Testing

### Overview
TestStore provides powerful capabilities for testing Effects with lock management, including the ability to wait for and verify non-synchronous Effect execution, including unlock processing.

### Key TestStore Methods
- **`await store.send(action)`**: Sends action and verifies synchronous state changes
- **`await store.receive(action)`**: Waits for asynchronous Effects to send actions and verifies state changes
- **`await store.finish()`**: Waits for all asynchronous processing to complete

### Effect Execution Testing
TestStore actually executes the internal asynchronous processing of Effects, including unlock processing. This enables comprehensive testing of the complete Effect lifecycle.

### Example: Basic Lock Effect Testing
```swift
func testLockEffectExecution() async {
  let container = LockmanStrategyContainer()
  let strategy = LockmanSingleExecutionStrategy()
  try? container.register(strategy)
  
  await LockmanManager.withTestContainer(container) {
    let store = await TestStore(initialState: TestFeature.State()) {
      TestFeature()
    }
    
    // Send action that triggers locked Effect
    await store.send(.fetch) {
      $0.isLoading = true
    }
    
    // Wait for Effect completion and verify state
    await store.receive(\.fetchCompleted) {
      $0.isLoading = false
      $0.count = 42
    }
    
    // Ensure all Effects complete (including unlock)
    await store.finish()
  }
}
```

### Advanced: Testing Unlock Execution
For testing unlock processing execution (addressing uncovered regions in Effect+LockmanInternal.swift):

```swift
class MockStrategyWithUnlockTracking: LockmanStrategy {
  var unlockCallCount = 0
  
  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    unlockCallCount += 1
  }
  // ... other required methods
}

func testUnlockExecutionVerification() async throws {
  let mockStrategy = MockStrategyWithUnlockTracking()
  let container = LockmanStrategyContainer()
  try container.register(mockStrategy)
  
  await LockmanManager.withTestContainer(container) {
    let store = await TestStore(initialState: TestState()) { TestReducer() }
    
    await store.send(.lockAction)
    await store.receive(.actionCompleted) 
    await store.finish()
    
    // Verify unlock was actually executed
    XCTAssertEqual(mockStrategy.unlockCallCount, 1)
  }
}
```

### Coverage Analysis
- **Target**: 100% code coverage for all critical components
- **Requirement**: All uncovered regions must be tested unless technically impossible
- **Implementation Approach**: Use TestStore integration with mock strategies for comprehensive testing
- **No Exceptions Rule**: Special justification required for any uncovered code paths

### 100% Coverage Rule
**All code must achieve 100% coverage unless there are exceptional technical limitations.** 

**Rationale:**
- Error handling is critical for production reliability
- Uncovered code paths represent potential bugs and security vulnerabilities
- Low-frequency execution does not justify reduced testing standards
- Complete test coverage ensures maintainability and prevents regressions

**Implementation:**
- Use TestStore for comprehensive Effect testing
- Create mock strategies to simulate all error conditions
- Test all error handlers, fallback paths, and edge cases
- Cover @unknown default cases and defensive programming constructs

### Code Coverage Measurement

**Command Line Coverage Measurement:**

1. **Run tests with coverage enabled:**
   ```bash
   swift test --enable-code-coverage --filter YourTestClassName
   ```

2. **Generate coverage report:**
   ```bash
   xcrun llvm-cov report .build/arm64-apple-macosx/debug/LockmanPackageTests.xctest/Contents/MacOS/LockmanPackageTests -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata | grep "YourSourceFile.swift"
   ```

3. **Show detailed coverage with line-by-line breakdown:**
   ```bash
   xcrun llvm-cov show .build/arm64-apple-macosx/debug/LockmanPackageTests.xctest/Contents/MacOS/LockmanPackageTests -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata -use-color | grep -A 50 "YourSourceFile.swift"
   ```

**Coverage Report Format:**
- **Functions**: Percentage of functions executed
- **Instantiations**: Percentage of template instantiations executed  
- **Lines**: Percentage of lines executed (primary metric)
- **Regions**: Percentage of code regions executed

**Example Output:**
```
Sources/Lockman/Composable/Effect+LockmanInternal.swift    58    54     6.90%    15    13    13.33%    307    245    20.20%    0    0    -
```
This shows: 20.20% line coverage (245/307 lines executed)

## Internal Test Implementation Rules

When implementing unit tests for internal components (especially Effect+LockmanInternal.swift), follow these strict rules:

### Test Implementation Rules
1. **対象ディレクトリ**: `/Users/takeshishimada/git/Lockman/Tests/LockmanTestsNew/Unit/Composable`
2. **1テストファイル＝1ソースコードファイル**
3. **カバレッジ100%を達成する必要最低限のテストケース**
4. **1テストファイルのテストコードを実装するたびに、テストカバレッジを実測する**
5. **テストケースの検討はultrathink5回検討する**
6. **テストされる側のソースコードを変更した方が良い場合は、作業を止めて確認する**
7. **１テストケース実装ごとに確認をしてもらう**
8. **カバレッジが向上しないテストケースは削除する**
9. **カバレッジ測定方法の統一**: Swift Package Managerのコマンドを使用
   - `swift test --enable-code-coverage --filter Effect+LockmanInternalTests`
   - `xcrun llvm-cov report .build/debug/LockmanPackageTests.xctest/Contents/MacOS/LockmanPackageTests -instr-profile .build/debug/codecov/default.profdata Sources/Lockman/Composable/Effect+LockmanInternal.swift`
10. **Region Coverage必須確認**: 行カバレッジだけでなく、分岐カバレッジも確認
    - `xcrun llvm-cov show ... -show-regions` でRegion Coverageを詳細確認
11. **テストケース命名規則**: テストする具体的な条件・分岐を名前に含める
    - 例: `testBuildLockEffectWithNonCancellableAction()`, `testLockWithNilUnlockOption()`
12. **Mock/Test用データの最小設計**: カバレッジ向上に必要な最小限のテストデータのみ作成

### Systematic Test Creation Methodology

#### Phase 1: Initial Happy Path Coverage
1. **メソッド単位の正常系テスト作成**
   - 対象ソースファイルの各メソッドに対して1つの正常系テストを作成
   - 最も基本的な成功パターンのみをテスト
   - 複雑な分岐は後のPhaseで対応

2. **初回カバレッジ測定**
   ```bash
   swift test --enable-code-coverage --filter [TestClassName]
   xcrun llvm-cov report .build/debug/LockmanPackageTests.xctest/Contents/MacOS/LockmanPackageTests -instr-profile=.build/debug/codecov/default.profdata [SourceFile].swift
   ```

3. **未達部分の特定**
   ```bash
   xcrun llvm-cov show ... | grep -E "^\s*[0-9]+\|\s*0\|"
   ```

#### Phase 2: Targeted Gap Coverage
1. **未カバー行の分析**
   - 各未カバー行の実行条件を特定
   - エラーハンドリング、分岐条件、@unknown defaultケースなどを分類

2. **追加テストケースの設計**
   - 未カバー行に到達するための最小限のテストケースを設計
   - 1テストケース追加ごとにカバレッジを測定

3. **カバレッジ改善の検証**
   - テスト追加後に即座にカバレッジを測定
   - 改善されない場合はテストケースを見直し

#### Phase 3: Real Execution Coverage (TestStore Integration)
1. **実行時コードパスのテスト**
   - `.run`ブロック内のコード（unlock実行、handler実行）
   - TestStoreを使用した実際のEffect実行テスト
   - 非同期処理の完全なライフサイクルテスト

2. **最終カバレッジ測定**
   - Region coverageを含む詳細分析
   - 技術的制約による未カバー部分の文書化

### Implementation Best Practices

#### メソッド分析手順
1. **ソースファイル構造解析**
   ```bash
   # 対象ファイルのpublic/internal メソッドを把握
   grep -n "func " [SourceFile].swift
   grep -n "static func " [SourceFile].swift
   ```

2. **テストクラス準備**
   ```swift
   final class [SourceFile]Tests: XCTestCase {
     // Phase 1: 各メソッドの基本正常系テスト
     func testMethodName_BasicSuccess() async throws { }
     
     // Phase 2: エラーケース、分岐条件テスト
     func testMethodName_SpecificErrorCase() async throws { }
     
     // Phase 3: TestStore統合テスト
     func testRealEffectExecution() async throws { }
   }
   ```

#### 効率的なテスト追加フロー
1. **1テストメソッド作成** → **カバレッジ測定** → **改善確認** → **次のテスト**
2. **改善されないテストは即座に削除**: 無駄なテストコードを蓄積しない
3. **TestStore使用判断**: 実行時コンテキストが必要な場合のみ使用
4. **Mock設計の最小化**: カバレッジ向上に直接寄与するMockのみ作成

#### Coverage Target Definition
- **Minimum Acceptable**: 95% line coverage
- **Target Achievement**: 99%+ line coverage  
- **Technical Limitation Acceptance**: @unknown default cases, unreachable defensive code
- **Documentation Requirement**: All uncovered lines must be justified with technical reasoning

#### Coverage Analysis Methodology
- **Primary Metric**: Region coverage over line coverage for accurate branch testing
- **Detailed Analysis**: Use `-show-regions` flag to identify uncovered code branches
- **Systematic Approach**: Create test cases specifically targeting uncovered regions
- **Technical Constraints Recognition**: Distinguish between testable uncovered code and technical limitations (e.g., Effect execution contexts, @unknown default cases)

### Practical Command Examples

#### Complete Test Implementation Workflow
```bash
# 1. Phase 1: Create basic happy path tests for each method
swift test --enable-code-coverage --filter [TestClassName]
xcrun llvm-cov report .build/debug/LockmanPackageTests.xctest/Contents/MacOS/LockmanPackageTests -instr-profile=.build/debug/codecov/default.profdata [SourceFile].swift

# 2. Identify uncovered lines
xcrun llvm-cov show .build/debug/LockmanPackageTests.xctest/Contents/MacOS/LockmanPackageTests -instr-profile=.build/debug/codecov/default.profdata [SourceFile].swift | grep -E "^\s*[0-9]+\|\s*0\|"

# 3. Phase 2: Add targeted tests for uncovered lines (repeat after each test)
swift test --enable-code-coverage --filter [TestClassName].testSpecificCase
xcrun llvm-cov report ... # Check improvement

# 4. Phase 3: Add TestStore integration tests for real execution paths
swift test --enable-code-coverage --filter [TestClassName]
xcrun llvm-cov report ... # Final coverage measurement
```

#### Region Coverage Analysis
```bash
# Detailed branch coverage analysis
xcrun llvm-cov show .build/debug/LockmanPackageTests.xctest/Contents/MacOS/LockmanPackageTests -instr-profile=.build/debug/codecov/default.profdata [SourceFile].swift -show-regions -line-coverage-gt=0

# Find specific line context
xcrun llvm-cov show ... | grep -A10 -B5 "[LineNumber]"
```

### Troubleshooting Common Issues

#### TestStore Integration
- **Strategy Registration Mismatch**: Ensure test actions use correct `strategyId`
- **Effect Execution Context**: Use `LockmanManager.withTestContainer()` for proper test environment
- **Exhaustive Testing**: Handle all `store.receive()` calls or use `store.exhaustivity = .off`

#### Coverage Measurement
- **LLVM Profile Errors**: Permission issues (can be ignored if tests pass)
- **Empty Coverage**: Verify test filter matches class name exactly
- **Inconsistent Results**: Clean build with `swift package clean` before measurement

#### @unknown default Cases
- **Technical Limitation**: Current Swift versions cannot reach these cases
- **Acceptable Uncovered**: Document as defensive programming for future enum extensions
- **No Test Required**: These represent impossible states in current implementation

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
