// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "CursorMania",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CursorMania",
            path: "Sources/CursorMania",
            swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .release))],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
