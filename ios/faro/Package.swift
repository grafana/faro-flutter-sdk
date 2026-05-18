// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to
// build this package.

import PackageDescription

let package = Package(
    name: "faro",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "faro", targets: ["faro"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/microsoft/plcrashreporter.git",
            from: "1.12.2"
        ),
    ],
    targets: [
        .target(
            name: "faro",
            dependencies: [
                .product(
                    name: "CrashReporter",
                    package: "plcrashreporter"
                ),
            ]
        )
    ]
)
