// swift-tools-version: 6.2
import PackageDescription

// The same core sources compile in the app and in this independent test harness.
let package = Package(
    name: "LyrxCore",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [.library(name: "LyrxCore", targets: ["LyrxCore"])],
    targets: [
        .target(name: "LyrxCore", path: "Lyrx/Core"),
        .testTarget(name: "LyrxCoreTests", dependencies: ["LyrxCore"])
    ],
    swiftLanguageModes: [.v6]
)
