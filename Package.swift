// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "WebWorkerKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "WebWorkerKit",
            targets: ["WebWorkerKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.16.0"),
    ],
    targets: [
        .target(
            name: "WebWorkerKit",
            dependencies: [
                "JavaScriptKit",
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit")
            ]
        ),
        .testTarget(
            name: "WebWorkerKitTests",
            dependencies: ["WebWorkerKit"]),
    ]
)
