// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SightSave",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SightSaveCore", targets: ["SightSaveCore"])
    ],
    targets: [
        .target(
            name: "SightSaveCore",
            path: "Sources/SightSaveCore"
        ),
        .testTarget(
            name: "SightSaveCoreTests",
            dependencies: ["SightSaveCore"],
            path: "Tests/SightSaveCoreTests"
        )
    ]
)
