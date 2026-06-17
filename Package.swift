// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DailyTodos",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DailyTodos", targets: ["DailyTodos"])
    ],
    targets: [
        .executableTarget(
            name: "DailyTodos",
            path: "Sources/DailyTodos",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
