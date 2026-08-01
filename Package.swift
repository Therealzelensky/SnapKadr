// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapKadr",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(path: "../Zelensky/Snap"),
        .package(name: "Kadr", path: "../Zelensky/Kadr/.worktrees/multi-source-layout"),
        .package(path: "../NotchHUDKit")
    ],
    targets: [
        .executableTarget(
            name: "SnapKadr",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "SnapKit", package: "Snap"),
                .product(name: "KadrKit", package: "Kadr"),
                .product(name: "NotchHUDKit", package: "NotchHUDKit")
            ],
            path: "Sources/SnapKadr",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
