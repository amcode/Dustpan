// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Dustpan",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DustpanCore", targets: ["DustpanCore"]),
        .executable(name: "Dustpan", targets: ["Dustpan"]),
    ],
    targets: [
        // Pure logic: the sweep/reveal state machine, auto-sweep timer, settings. Fully unit-tested.
        .target(name: "DustpanCore", path: "Sources/DustpanCore"),
        // The menu bar app: two status items and a hot key. Thin wiring over the core.
        .executableTarget(
            name: "Dustpan",
            dependencies: ["DustpanCore"],
            path: "Sources/Dustpan",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]),
        .testTarget(
            name: "DustpanCoreTests",
            dependencies: ["DustpanCore"],
            path: "Tests/DustpanCoreTests"),
    ]
)
