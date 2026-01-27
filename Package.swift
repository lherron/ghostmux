// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ghostmux",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ghostmux", targets: ["ghostmux"]),
        .executable(name: "ghostchat", targets: ["ghostchat"])
    ],
    targets: [
        .target(
            name: "GhosttyLib",
            path: "Sources/GhosttyLib"
        ),
        .executableTarget(
            name: "ghostmux",
            dependencies: ["GhosttyLib"],
            path: "Sources/ghostmux"
        ),
        .executableTarget(
            name: "ghostchat",
            dependencies: ["GhosttyLib"],
            path: "Sources/ghostchat"
        )
    ]
)
