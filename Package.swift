// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "stash-it",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "stash-it",
            path: "Sources/stash-it"
        )
    ]
)
