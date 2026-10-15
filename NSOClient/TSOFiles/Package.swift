// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TSOFiles",
    products: [
        .library(name: "TSOFiles", targets: ["TSOFiles"]),
    ],
    targets: [
        .target(name: "TSOFiles"),
        .testTarget(name: "TSOFilesTests", dependencies: ["TSOFiles"]),
    ],
    swiftLanguageModes: [.v6]
)
