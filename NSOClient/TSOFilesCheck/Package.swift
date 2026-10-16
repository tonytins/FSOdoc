// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TSOFilesCheck",
    // A tool, so it may require a newer macOS than the libraries (see AGENTS.md, rule 5).
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "tsofiles-check", targets: ["TSOFilesCheck"]),
    ],
    dependencies: [
        .package(path: "../TSOFiles"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(name: "TSOFilesCheck", dependencies: [
            .product(name: "TSOFiles", package: "TSOFiles"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "TSOFilesCheckTests", dependencies: [
            "TSOFilesCheck",
            .product(name: "TSOFiles", package: "TSOFiles"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
