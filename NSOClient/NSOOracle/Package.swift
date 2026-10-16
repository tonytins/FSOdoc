// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NSOOracle",
    products: [
        .executable(name: "nso-oracle", targets: ["NSOOracle"]),
    ],
    dependencies: [
        .package(path: "../TSOFiles"),
        .package(path: "../TSOContent"),
        .package(path: "../SimAntics"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "NSOOracleCore", dependencies: [
            .product(name: "TSOFiles", package: "TSOFiles"),
            .product(name: "TSOContent", package: "TSOContent"),
            .product(name: "SimAntics", package: "SimAntics"),
        ]),
        .executableTarget(name: "NSOOracle", dependencies: [
            "NSOOracleCore",
            .product(name: "TSOContent", package: "TSOContent"),
            .product(name: "SimAntics", package: "SimAntics"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "NSOOracleTests", dependencies: [
            "NSOOracleCore",
            .product(name: "TSOContent", package: "TSOContent"),
            .product(name: "SimAntics", package: "SimAntics"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
