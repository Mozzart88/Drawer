// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Drawer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Drawer",
            path: "Sources/Drawer",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
