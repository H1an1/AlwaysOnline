// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AlwaysOnline",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AlwaysOnlineCore",
            targets: ["AlwaysOnlineCore"]
        ),
        .executable(
            name: "AlwaysOnline",
            targets: ["AlwaysOnlineMac"]
        )
    ],
    targets: [
        .target(
            name: "AlwaysOnlineCore"
        ),
        .executableTarget(
            name: "AlwaysOnlineMac",
            dependencies: ["AlwaysOnlineCore"]
        ),
        .testTarget(
            name: "AlwaysOnlineCoreTests",
            dependencies: ["AlwaysOnlineCore"]
        )
    ]
)
