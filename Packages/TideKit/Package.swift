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
    ],
    targets: [
        .target(name: "TideKit", resources: [.process("Resources")]),
        .target(name: "TideUI", dependencies: ["TideKit"]),
        .executableTarget(name: "CatalogBuilder", dependencies: ["TideKit"]),
        .testTarget(
            name: "TideKitTests",
            dependencies: ["TideKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
