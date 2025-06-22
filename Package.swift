// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "Lockman",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    // Core functionality without TCA dependency
    .library(
      name: "LockmanCore",
      targets: ["LockmanCore"]),
    // TCA integration
    .library(
      name: "LockmanComposable",
      targets: ["LockmanComposable"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.17.1"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"602.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.2.0"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4"),
  ],
  targets: [
    // Core target without TCA dependency
    .target(
      name: "LockmanCore",
      dependencies: [
        .product(name: "OrderedCollections", package: "swift-collections")
      ]
    ),
    // TCA integration target
    .target(
      name: "LockmanComposable",
      dependencies: [
        "LockmanCore",
        "LockmanMacros",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .macro(
      name: "LockmanMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "LockmanCoreTests",
      dependencies: [
        "LockmanCore"
      ]
    ),
    .testTarget(
      name: "LockmanComposableTests",
      dependencies: [
        "LockmanCore",
        "LockmanComposable",
      ]
    ),
    .testTarget(
      name: "LockmanMacrosTests",
      dependencies: [
        "LockmanMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
  ]
)

#if compiler(>=6)
  for target in package.targets where target.type != .system && target.type != .test {
    target.swiftSettings = target.swiftSettings ?? []
    target.swiftSettings?.append(contentsOf: [
      .enableExperimentalFeature("StrictConcurrency"),
      .enableUpcomingFeature("ExistentialAny"),
      .enableUpcomingFeature("InferSendableFromCaptures"),
    ])
  }
#endif
