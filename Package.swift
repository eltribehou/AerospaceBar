// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AerospaceMenubar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AerospaceMenubar",
            targets: ["AerospaceMenubar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AerospaceMenubar",
            path: "Sources"
        )
    ]
)
