// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "xccov-json-to-sonar-xml",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.14.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "xccov-json-to-sonar-xml",
            dependencies: [
                .product(name: "XMLCoder", package: "XMLCoder"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
    ]
)
