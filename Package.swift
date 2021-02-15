// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "HTMLFastParse",
    platforms: [
        .macOS(.v10_11), .iOS(.v9),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "HTMLFastParse",
            targets: ["HTMLFastParse"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HTMLFastParse",
            path: "./HTMLFastParse",
            publicHeadersPath: "Headers"
        )
    ]
)

