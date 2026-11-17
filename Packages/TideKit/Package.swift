// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TideKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TideKit", targets: ["TideKit"]),
        .library(name: "TideUI", targets: ["TideUI"]),
        .executable(name: "catalog-builder", targets: ["CatalogBuilder"]),
        .executable(name: "art-forge", targets: ["ArtForge"]),
    ],
    targets: [
        .target(name: "TideKit", resources: [.process("Resources")]),
        .target(name: "TideUI", dependencies: ["TideKit"], resources: [.copy("Fonts"), .copy("Scenes"), .process("Shaders")]),
        .executableTarget(name: "CatalogBuilder", dependencies: ["TideKit"]),
        // Offline asset tool; single-threaded, so Swift 5 mode is sufficient.
        .executableTarget(name: "ArtForge", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "TideKitTests",
            dependencies: ["TideKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
