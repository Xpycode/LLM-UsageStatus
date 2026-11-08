// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FeedbackKit", platforms: [.macOS(.v14)],
    products: [.library(name: "FeedbackKit", targets: ["FeedbackKit"])],
    targets: [.target(name: "FeedbackKit")])
