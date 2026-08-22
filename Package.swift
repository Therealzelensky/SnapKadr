// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapKadr",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        // Suite-only SnapKit worktree (autonomous in-process). Companion Snap checkout stays separate.
        .package(name: "Snap", path: "../../Snap/Snap/.worktrees/suite-embed"),
        .package(name: "Kadr", path: "../../Kadr/Kadr/.worktrees/multi-source-layout"),
        .package(path: "../../NotchHUDKit")
    ],
    targets: [
        .target(
            name: "StenoKit",
            path: "Sources/StenoKit",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .executableTarget(
            name: "SnapKadr",
            dependencies: [
                "StenoKit",
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
