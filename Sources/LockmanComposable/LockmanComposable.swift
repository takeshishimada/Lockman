/// ## Topics
/// ### Getting Started
/// - <doc:QuickStart>
/// - <doc:Installation>
public enum LockmanComposable {
    // This enum serves as a namespace for documentation
}

// Re-export everything from LockmanCore to make it available through LockmanComposable
@_exported import LockmanCore

// This file ensures that when users import LockmanComposable, they get:
// 1. All LockmanCore functionality (including macros)
// 2. TCA integration (Effect+Lockman)
// 3. A single import statement for all Lockman features when using TCA
