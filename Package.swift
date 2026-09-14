// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeBalance",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeBalance",
            path: "Sources/ClaudeBalance"
        )
    ]
)
