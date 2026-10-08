// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "macos-calendar-mcp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "macos-calendar-mcp", targets: ["macos-calendar-mcp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
    ],
    targets: [
        .target(
            name: "MacOSCalendarMCP",
            dependencies: [.product(name: "MCP", package: "swift-sdk")]
        ),
        .executableTarget(name: "macos-calendar-mcp", dependencies: ["MacOSCalendarMCP"]),
        .testTarget(name: "MacOSCalendarMCPTests", dependencies: ["MacOSCalendarMCP"]),
    ],
    swiftLanguageModes: [.v6]
)
