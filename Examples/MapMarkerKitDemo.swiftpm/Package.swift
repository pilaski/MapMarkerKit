// swift-tools-version: 5.9

// An example Swift Playgrounds app that demonstrates MapMarkerKit. Open this
// `.swiftpm` in Swift Playgrounds or Xcode. It depends on the MapMarkerKit package
// at the repository root via a relative path, so it always builds against the
// local source.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "MapMarkerKitDemo",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "MapMarkerKitDemo",
            targets: ["AppModule"],
            bundleIdentifier: "net.pilaski.mapmarkerkitdemo",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .map),
            accentColor: .presetColor(.purple),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pilaski/MapMarkerKit.git", branch: "claude/mapmarkerkit-refactor-pn1r5x")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "MapMarkerKit", package: "MapMarkerKit")
            ],
            path: ".",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        )
    ]
)
