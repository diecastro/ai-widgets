// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIUsage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "UsageCore", targets: ["UsageCore"]),
        .executable(name: "usage-probe", targets: ["usage-probe"]),
        .executable(name: "AIUsageMenuBar", targets: ["AIUsageMenuBar"])
    ],
    targets: [
        .target(name: "UsageCore"),
        .executableTarget(name: "usage-probe", dependencies: ["UsageCore"]),
        .executableTarget(
            name: "AIUsageMenuBar",
            dependencies: ["UsageCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "UsageCoreTests",
            dependencies: ["UsageCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
