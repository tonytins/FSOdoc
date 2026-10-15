// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TSOContent",
    products: [
        .library(name: "TSOContent", targets: ["TSOContent"]),
    ],
    dependencies: [
        .package(path: "../TSOFiles"),
    ],
    targets: [
        .target(name: "TSOContent", dependencies: ["TSOFiles"]),
        .testTarget(name: "TSOContentTests", dependencies: ["TSOContent", "TSOFiles"]),
    ],
    swiftLanguageModes: [.v6]
)
