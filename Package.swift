// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MapMarkerKit",
    platforms: [
        .iOS(.v17),
        // Markers render through Core Graphics with a thin UIKit/AppKit shim
        // (Platform.swift), so the kit builds for Mac as well. v14 is what the
        // SF Symbol configuration APIs used here need.
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MapMarkerKit",
            targets: ["MapMarkerKit"]
        )
    ],
    targets: [
        .target(
            name: "MapMarkerKit"
        ),
        .testTarget(
            name: "MapMarkerKitTests",
            dependencies: ["MapMarkerKit"]
        )
    ]
)
