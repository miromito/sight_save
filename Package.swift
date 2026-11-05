// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [
    .library(name: "SightSaveCore", targets: ["SightSaveCore"])
]

var targets: [Target] = [
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

// Menu bar app (AppKit / AVFoundation) — macOS only. Keeps `swift test` usable on Linux CI.
#if os(macOS)
// Product name differs from the .app / Xcode target ("SightSave") to avoid SPM↔Xcode clashes.
// scripts/build.sh renames the binary to SightSave inside the app bundle.
products.append(
    .executable(name: "SightSaveApp", targets: ["SightSaveApp"])
)
targets.append(
    .executableTarget(
        name: "SightSaveApp",
        dependencies: ["SightSaveCore"],
        path: "App/SightSave",
        exclude: [
            // Bundled by scripts/build.sh (and Xcode); not needed as SPM resources.
            "Resources"
        ]
    )
)
#endif

let package = Package(
    name: "SightSave",
    platforms: [
        .macOS(.v13)
    ],
    products: products,
    targets: targets
)
