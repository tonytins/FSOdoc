// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SimsScript",
    products: [
        .library(name: "SimsScript", targets: ["SimsScript"]),
    ],
    dependencies: [
        .package(path: "../SimAntics"),
        .package(path: "../TSOContent"),
        .package(path: "../TSOFiles"),
    ],
    targets: [
        .target(name: "SimsScript", dependencies: [
            .product(name: "SimAntics", package: "SimAntics"),
            .product(name: "TSOFiles", package: "TSOFiles"),
        ]),
        .testTarget(name: "SimsScriptTests", dependencies: [
            "SimsScript",
            .product(name: "SimAntics", package: "SimAntics"),
            .product(name: "TSOContent", package: "TSOContent"),
            .product(name: "TSOFiles", package: "TSOFiles"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
