// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "smartSync2",
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/dominicegginton/Spinner", from: "2.1.0"),
        .package(url: "https://github.com/mtynior/ColorizeSwift", from: "1.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "smartSync2", dependencies: [
                // other dependencies
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Spinner", package: "Spinner"),
                .product(name: "ColorizeSwift", package: "ColorizeSwift"),
        ]),
    ]
)
