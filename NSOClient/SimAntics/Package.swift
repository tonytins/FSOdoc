// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SimAntics",
    products: [
        .library(name: "SimAntics", targets: ["SimAntics"]),
    ],
    dependencies: [
        .package(path: "../TSOContent"),
        .package(path: "../TSOFiles"),
    ],
    targets: [
        .target(name: "SimAntics", dependencies: ["TSOContent", "TSOFiles"]),
        .testTarget(name: "SimAnticsTests", dependencies: ["SimAntics"]),
    ],
    swiftLanguageModes: [.v6]
)
