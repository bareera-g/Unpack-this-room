// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "UnpackTheRoom",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "UnpackTheRoom",
            targets: ["UnpackTheRoom"]
        )
    ],
    targets: [
        .target(
            name: "UnpackTheRoom",
            path: "Sources"
        ),
        .testTarget(
            name: "UnpackTheRoomTests",
            dependencies: ["UnpackTheRoom"],
            path: "Tests"
        )
    ]
)

