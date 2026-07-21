// swift-tools-version:5.9
import PackageDescription

// Plannus — a SwiftUI task planner (port of the original React Native app).
//
// This package builds the app's source as a library target so it can be
// type-checked from the command line (`swift build`) even without full Xcode.
// To run it, add these sources to an iOS App target in Xcode; `PlannusApp` is
// the `@main` entry point.
let package = Package(
    name: "Plannus",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "Plannus", targets: ["Plannus"])
    ],
    targets: [
        .target(name: "Plannus"),
        .testTarget(name: "PlannusTests", dependencies: ["Plannus"])
    ]
)
