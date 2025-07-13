# Lockman 1.2.0 Release Notes

## 🚀 Major New Features

### Automatic Cancellation ID Management
- **Eliminate manual cancellation ID specification**: No need to manually add `.cancellable(id: boundaryId)` when using `.run()` methods with Lockman's lock functionality
- **Automatic application**: All Effect.lock methods now automatically apply cancellation IDs
- **Simplified API**: Cleaner, more intuitive code with reduced boilerplate

#### Before (v1.1.0):
```swift
return .run { send in
  await send(.completed)
}
.cancellable(id: boundaryId)  // Manual specification required
.lock(action: action, boundaryId: boundaryId)
```

#### After (v1.2.0):
```swift
return .run { send in
  await send(.completed)
}
.lock(action: action, boundaryId: boundaryId)  // Automatic application!
```

## 🛡️ Enhanced Safety & Reliability

### Guaranteed Resource Cleanup Design Principle
- **Resource cleanup is guaranteed**: Lock release always executes regardless of cancellation
- **Operations are cancellable**: Business logic can be cancelled while ensuring proper cleanup
- **Deadlock prevention**: Fixed potential deadlock scenarios in concatenated operations

### Improved Cancellation Scope Management
- **Precise cancellation control**: Only business operations are cancellable, not resource cleanup
- **Safer concatenated operations**: Enhanced `Effect.withLock(concatenating:)` with proper cancellation scope
- **Consistent error handling**: Improved error handling patterns across all withLock variants

## 📚 Comprehensive Documentation

### Enhanced API Documentation
- **Before/after examples**: Clear migration guidance showing manual vs automatic cancellation
- **Design principles**: Detailed explanation of "Guaranteed Resource Cleanup" principle
- **Usage patterns**: Comprehensive examples for all Effect.withLock variants
- **Method chaining examples**: Demonstrations of clean, chain-style API usage

## 🧪 Robust Testing

### New Test Coverage
- **Automatic cancellation tests**: 5 comprehensive test cases verifying automatic behavior
- **Concurrent operation tests**: Validation of proper blocking and resource management
- **Edge case coverage**: Testing empty operations, multiple boundaries, and error scenarios
- **Regression prevention**: All existing tests continue to pass with no breaking changes

## 🔄 Migration Guide

### Updating to v1.2.0

This release is **fully backward compatible**. No code changes are required, but you can simplify existing code:

1. **Remove manual `.cancellable(id:)` calls** when using `.lock()` methods
2. **Leverage automatic cancellation** for cleaner, more maintainable code
3. **Review concatenated operations** for potential simplification opportunities

### Package Manager Update

Update your Package.swift dependency:

```swift
.package(url: "https://github.com/takeshishimada/Lockman", from: "1.2.0")
```

## ⚡ Performance & Compatibility

- **Zero performance impact**: Automatic cancellation adds no runtime overhead
- **Full backward compatibility**: Existing code continues to work without modification
- **TCA 1.20.2 compatibility**: Fully tested with The Composable Architecture 1.20.2
- **All platforms supported**: iOS, macOS, tvOS, watchOS, Mac Catalyst

## 🎯 What's Next

- Enhanced Examples project showcasing automatic cancellation features
- Additional strategy patterns for complex use cases
- Performance optimizations for large-scale applications

---

For complete documentation and examples, visit: https://takeshishimada.github.io/Lockman/1.2.0/documentation/lockman/