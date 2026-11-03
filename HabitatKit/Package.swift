// swift-tools-version: 6.2
import PackageDescription

let strictSettings: [SwiftSetting] = [
    .treatAllWarnings(as: .error)
]

let package = Package(
    name: "HabitatKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "HabitatCore", targets: ["HabitatCore"]),
        .library(name: "HabitatData", targets: ["HabitatData"])
    ],
    targets: [
        .target(
            name: "HabitatCore",
            swiftSettings: strictSettings
        ),
        .target(
            name: "HabitatData",
            dependencies: ["HabitatCore"],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "HabitatCoreTests",
            dependencies: ["HabitatCore"],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "HabitatDataTests",
            dependencies: ["HabitatData", "HabitatCore"],
            swiftSettings: strictSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
