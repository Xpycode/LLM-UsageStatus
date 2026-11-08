// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "HelpMenu", platforms: [.macOS(.v14)],
    products: [.library(name: "HelpMenu", targets: ["HelpMenu"])],
    dependencies: [.package(url: "https://github.com/gonzalezreal/swift-markdown-ui", exact: "2.4.1")],
    targets: [.target(name: "HelpMenu", dependencies: [.product(name: "MarkdownUI", package: "swift-markdown-ui")])])
