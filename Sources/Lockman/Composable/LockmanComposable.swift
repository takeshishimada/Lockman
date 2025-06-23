// This file is now part of the unified Lockman module
// No need to import LockmanCore as we're in the same module

// This file ensures that when users import LockmanComposable, they get:
// 1. All LockmanCore functionality (including macros)
// 2. TCA integration (Effect+Lockman)
// 3. A single import statement for all Lockman features when using TCA
