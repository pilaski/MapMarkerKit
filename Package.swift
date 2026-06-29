// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MapMarkerKit",
    platforms: [
        .iOS(.v17)
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
