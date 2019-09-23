  // swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Cycler",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Cycler",
            targets: ["Cycler"]),
    ],
    targets: [
        .target(
            name: "Cycler",
            dependencies: [],
            path: "Sources"),
    ],
    swiftLanguageVersions: [
        .version("5.1")
    ]
)
