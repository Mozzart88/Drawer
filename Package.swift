// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Drawer",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DrawerCore",
            path: "Sources/Drawer",
            exclude: ["main.swift"],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "Drawer",
            dependencies: ["DrawerCore"],
            path: "Sources/DrawerMain"
        ),
        .testTarget(
            name: "DrawerTests",
            dependencies: ["DrawerCore"],
            path: "Tests/DrawerTests"
        )
    ]
)
