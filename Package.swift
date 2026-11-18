// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "CursorSpaceX",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "CursorSpaceX",
            path: "Sources/CursorSpaceX",
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
