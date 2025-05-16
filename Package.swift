// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "WebWorkerKit",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
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
