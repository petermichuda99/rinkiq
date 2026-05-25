// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PrizeRinkIQKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "PrizeRinkIQKit",
            targets: ["PrizeRinkIQKit"]
        )
    ],
    targets: [
        .target(name: "PrizeRinkIQKit")
    ]
)
