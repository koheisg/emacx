// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Emacx",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Emacx", targets: ["Emacx"])
    ],
    targets: [
        .executableTarget(
            name: "Emacx",
            path: "Sources/Emacx",
            resources: [.process("../../Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
