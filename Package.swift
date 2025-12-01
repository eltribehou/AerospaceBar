// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AerospaceBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AerospaceBar",
            targets: ["AerospaceBar"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "AerospaceBar",
            dependencies: ["TOMLKit"],
            path: "Sources"
        )
    ]
)
