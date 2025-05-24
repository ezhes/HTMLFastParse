// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "HTMLFastParse",
    platforms: [
        .macOS(.v10_11), .iOS(.v13),
    ],
    products: [
        .library(
            name: "HTMLFastParse",
            targets: ["HTMLFastParse"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "HTMLFastParse",
            dependencies: [],
            path: "./Sources/HTMLSwiftParser"
        ),
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
