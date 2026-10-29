// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OverscrollEmit",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic (CLI parsing, style resolution, geometry, IPC payloads). No AppKit.
        .target(name: "OverscrollEmitCore"),
        // Resident agent app. Bundled as OverscrollEmit.app/Contents/MacOS/OverscrollEmit by scripts/build.sh.
        .executableTarget(name: "OverscrollEmitApp", dependencies: ["OverscrollEmitCore"]),
        // CLI. Bundled as OverscrollEmit.app/Contents/Helpers/overscroll-emit by scripts/build.sh.
        .executableTarget(name: "overscroll-emit-cli", dependencies: ["OverscrollEmitCore"]),
        .testTarget(name: "OverscrollEmitCoreTests", dependencies: ["OverscrollEmitCore"]),
    ]
)
