// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SprayCan",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SprayCanCore", targets: ["SprayCanCore"]),
               .executable(name: "SprayCan", targets: ["SprayCanApp"])],
    targets: [.target(name: "SprayCanCore"),
              .executableTarget(name: "SprayCanApp", dependencies: ["SprayCanCore"]),
              .testTarget(name: "SprayCanCoreTests", dependencies: ["SprayCanCore"])])
