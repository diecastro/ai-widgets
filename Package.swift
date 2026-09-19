// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "AIUsage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "UsageCore", targets: ["UsageCore"]),
        .executable(name: "usage-probe", targets: ["usage-probe"])
    ],
    targets: [
        .target(name: "UsageCore"),
        .executableTarget(name: "usage-probe", dependencies: ["UsageCore"]),
        .testTarget(
            name: "UsageCoreTests",
            dependencies: ["UsageCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
