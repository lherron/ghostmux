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
        .target(
            name: "GhostmuxCommandParsing",
            path: "Sources/GhostmuxCommandParsing"
        ),
        .executableTarget(
            name: "ghostmux",
            dependencies: ["GhosttyLib", "GhostmuxCommandParsing"],
            path: "Sources/ghostmux"
        ),
        .executableTarget(
            name: "ghostchat",
            dependencies: ["GhosttyLib"],
            path: "Sources/ghostchat"
        ),
        .testTarget(
            name: "GhosttyLibTests",
            dependencies: ["GhosttyLib"],
            path: "Tests/GhosttyLibTests"
        ),
        .testTarget(
            name: "GhostmuxCommandParsingTests",
            dependencies: ["GhostmuxCommandParsing"],
            path: "Tests/GhostmuxCommandParsingTests"
        )
    ]
)
