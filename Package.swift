// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ghostmux",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ghostmux", targets: ["ghostmux"])
    ],
    targets: [
        .executableTarget(
            name: "ghostmux",
            path: "Sources/ghostmux"
        )
    ]
)
