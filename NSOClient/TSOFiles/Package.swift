// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TSOFiles",
    products: [
        .library(name: "TSOFiles", targets: ["TSOFiles"]),
        .executable(name: "tsofiles-check", targets: ["TSOFilesCheck"]),
    ],
    targets: [
        .target(name: "TSOFiles"),
        .executableTarget(name: "TSOFilesCheck", dependencies: ["TSOFiles"]),
        .testTarget(name: "TSOFilesTests", dependencies: ["TSOFiles"]),
        .testTarget(name: "TSOFilesCheckTests", dependencies: ["TSOFilesCheck"]),
    ],
    swiftLanguageModes: [.v6]
)
