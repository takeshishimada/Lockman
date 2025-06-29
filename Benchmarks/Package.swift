// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "benchmarks",
  platforms: [
    .macOS("14")
  ],
  dependencies: [
    .package(path: ".."),
    .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.4.0"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.20.1"),
  ],
  targets: [
    .executableTarget(
      name: "LockmanBenchmarks",
      dependencies: [
        .product(name: "Lockman", package: "Lockman"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Benchmark", package: "package-benchmark"),
      ],
      path: "Benchmarks/Lockman",
      plugins: [
        .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
      ]
    )
  ]
)
