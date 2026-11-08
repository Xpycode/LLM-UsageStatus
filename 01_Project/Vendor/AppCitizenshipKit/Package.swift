// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AppCitizenshipKit", platforms: [.macOS(.v14)],
    products: [.library(name: "AppCitizenshipKit", targets: ["AppCitizenshipKit"])],
    dependencies: [.package(path: "../FeedbackKit")],
    targets: [.target(name: "AppCitizenshipKit", dependencies: [.product(name: "FeedbackKit", package: "FeedbackKit")])])
