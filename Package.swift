// swift-tools-version:5.10
import PackageDescription

// `swift test` runs the core's unit tests; `swift run Bearings` runs the Mac app in development.
// Release builds (Mac and iPhone) come from project.yml through XcodeGen: see scripts/build-app.sh.
let package = Package(
    name: "Bearings",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Bearings", path: "Sources/Bearings"),
        .testTarget(name: "BearingsTests", dependencies: ["Bearings"], path: "Tests/BearingsTests"),
    ]
)
