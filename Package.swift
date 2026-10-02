// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "RAWCore", platforms: [.macOS("27.0"), .iOS("27.0")], products: [.library(name: "RAWCore", targets: ["RAWCore"])], targets: [.target(name: "RAWCore", path: "Sources/Core"), .testTarget(name: "RAWCoreTests", dependencies: ["RAWCore"], path: "Tests/Core")])
