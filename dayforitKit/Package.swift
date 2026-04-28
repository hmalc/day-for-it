// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "dayforitKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PleasantnessEngine", targets: ["PleasantnessEngine"]),
        .library(name: "WeatherCore", targets: ["WeatherCore"]),
    ],
    targets: [
        .target(name: "PleasantnessEngine"),
        .target(
            name: "WeatherCore",
            dependencies: ["PleasantnessEngine"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PleasantnessEngineTests",
            dependencies: ["PleasantnessEngine"]
        ),
        .testTarget(
            name: "WeatherCoreTests",
            dependencies: ["WeatherCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
