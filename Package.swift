// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "HTMLFastParse", // Package name itself is fine
    platforms: [
        .macOS(.v10_11), .iOS(.v9),
    ],
    products: [
        .library(
            name: "HTMLFastParse",
            targets: ["HTMLFastParse"]), // Changed
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "HTMLFastParse", // This name is correct (module name)
            dependencies: [],
            path: "Sources/HTMLSwiftParser" // Change path back to this
        ),
        // Other targets like tests and demo app might exist here
        .testTarget(
            name: "HTMLFastParseTests",
            dependencies: ["HTMLFastParse"],
            path: "HTMLFastParseTests",
            resources: [
                .copy("TestData.plist"),
                .copy("AnswerData.plist"),
                .copy("2MB_dev_random.txt"),
                .copy("non_utf8_fuzzer_crash.txt")
            ]
        ),
    ]
)
