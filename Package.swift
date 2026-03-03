// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "PlaybackDiagnostics",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "PlaybackDiagnostics", targets: ["PlaybackDiagnostics"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.4"),
    ],
    targets: [
        .target(
            name: "MacroPluginUtilities",
            dependencies: [
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                        ],
            path: "Sources/MacroPluginUtilities"
        ),

        .macro(
            name: "PlaybackDiagnosticsMacroPlugin",
            dependencies: [
                "MacroPluginUtilities",
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "PlaybackDiagnostics",
            dependencies: ["PlaybackDiagnosticsMacroPlugin"]
        ),

        .testTarget(
            name: "MacroPluginUtilitiesTests",
            dependencies: [
                "MacroPluginUtilities",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "PlaybackDiagnosticsTests",
            dependencies: [
                "PlaybackDiagnostics",
                "PlaybackDiagnosticsMacroPlugin",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
    ]
)
