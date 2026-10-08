import MacOSCalendarMCP
import Foundation

if ListMode.isRequested(environment: ProcessInfo.processInfo.environment) {
    exit(await ListMode.run(source: EventKitCalendars()))
}

do {
    let settings = try Settings.parse(arguments: CommandLine.arguments, environment: ProcessInfo.processInfo.environment)
    let context = ToolContext(
        source: EventKitCalendars(), access: CalendarAccess(settings: settings), mirror: MirrorProvider(path: settings.mirrorPath)
    )
    try await CalendarServer.start(context: context)
} catch {
    FileHandle.standardError.write(Data("[macos-calendar-mcp] \(error)\n".utf8))
    exit(1)
}
