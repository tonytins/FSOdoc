// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SimAnticsScript",
    products: [
        .library(name: "SimAnticsScript", targets: ["SimAnticsScript"]),
    ],
    dependencies: [
        .package(path: "../SimAntics"),
        .package(path: "../TSOContent"),
        .package(path: "../TSOFiles"),
    ],
    targets: [
        .target(name: "SimAnticsScript", dependencies: [
            .product(name: "SimAntics", package: "SimAntics"),
            .product(name: "TSOFiles", package: "TSOFiles"),
        ]),
        .testTarget(name: "SimAnticsScriptTests", dependencies: [
            "SimAnticsScript",
            .product(name: "SimAntics", package: "SimAntics"),
            .product(name: "TSOContent", package: "TSOContent"),
            .product(name: "TSOFiles", package: "TSOFiles"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
