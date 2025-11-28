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
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "AerospaceMenubar",
            dependencies: ["TOMLKit"],
            path: "Sources"
        )
    ]
)
