// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AHKDynamicIsland",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AHKDynamicIsland",
            targets: ["AHKDynamicIsland"]
        ),
        .library(
            name: "AHKDynamicIslandCore",
            targets: ["AHKDynamicIslandCore"]
        )
    ],
    targets: [
        .target(
            name: "AHKDynamicIslandCore",
            path: "Sources/AHKDynamicIslandCore"
        ),
        .executableTarget(
            name: "AHKDynamicIsland",
            dependencies: ["AHKDynamicIslandCore"],
            path: "Sources/AHKDynamicIsland"
        ),
        .testTarget(
            name: "AHKDynamicIslandTests",
            dependencies: ["AHKDynamicIslandCore"],
            path: "Tests/AHKDynamicIslandTests"
        )
    ]
)
