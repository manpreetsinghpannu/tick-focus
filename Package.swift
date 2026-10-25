// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Tick",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Tick", path: "Sources/Tick")
    ]
)
