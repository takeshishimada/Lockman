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
    // Unified Lockman library
    .library(
      name: "Lockman",
      targets: ["Lockman"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.21.1"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"602.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.3"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.5"),
  ],
  targets: [
    // Unified Lockman target
    .target(
      name: "Lockman",
      dependencies: [
        "LockmanMacros",
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      path: "Sources/Lockman"
    ),
    .macro(
      name: "LockmanMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "LockmanTests",
      dependencies: [
        "Lockman"
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
