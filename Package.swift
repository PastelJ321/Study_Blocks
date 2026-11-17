// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "StudyBlocks", platforms: [.macOS(.v14)],
    products: [.library(name: "StudyCore", targets: ["StudyCore"]), .executable(name: "PersistenceProbe", targets: ["PersistenceProbe"])],
    targets: [.target(name: "StudyCore", path: "StudyBlocks/Core"),
              .executableTarget(name: "PersistenceProbe", dependencies: ["StudyCore"], path: "Tools/Probe"),
              .testTarget(name: "StudyCoreTests", dependencies: ["StudyCore"], path: "Tests/StudyCoreTests")]
)
