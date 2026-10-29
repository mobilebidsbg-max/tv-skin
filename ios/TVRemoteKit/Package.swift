// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TVRemoteKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TVRemoteKit", targets: ["TVRemoteKit"]),
        .executable(name: "tvremote", targets: ["tvremote"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.27.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.4.0"),
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "TVRemoteKit",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "SwiftASN1", package: "swift-asn1"),
            ]
        ),
        .executableTarget(
            name: "tvremote",
            dependencies: ["TVRemoteKit"]
        ),
        .testTarget(
            name: "TVRemoteKitTests",
            dependencies: ["TVRemoteKit"]
        ),
    ]
)
