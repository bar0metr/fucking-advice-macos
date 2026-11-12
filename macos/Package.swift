// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FuckingAdviceCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "FuckingAdviceCore", targets: ["FuckingAdviceCore"])],
    targets: [
        .target(name: "FuckingAdviceCore", path: "Shared"),
        .testTarget(name: "FuckingAdviceCoreTests", dependencies: ["FuckingAdviceCore"], path: "Tests/SwiftCoreTests")
    ]
)
