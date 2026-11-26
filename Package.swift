// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Proofly",
    platforms: [.macOS("15.1")],
    products: [.executable(name: "Proofly", targets: ["Proofly"])],
    targets: [
        .executableTarget(
            name: "Proofly",
            path: "Sources/Proofly",
            exclude: ["Info.plist", "Proofly.entitlements"]
        )
    ]
)
