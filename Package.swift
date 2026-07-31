// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapKadr",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        // Worktree: Snap feature/prefs-polish (sibling path stays ../Zelensky/Snap for main checkout)
        .package(path: "../Zelensky/Snap/.worktrees/prefs-polish"),
        .package(path: "../NotchHUDKit")
    ],
    targets: [
        .executableTarget(
            name: "SnapKadr",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                // Local worktree folder name becomes the package identity for path deps.
                .product(name: "SnapKit", package: "prefs-polish"),
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
