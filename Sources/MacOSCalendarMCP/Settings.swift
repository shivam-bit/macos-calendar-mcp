import Foundation

public struct Settings: Equatable, Sendable {
    public var blockedAccountIds: Set<String>
    public var blockedCalendarIds: Set<String>
    public var mirrorPath: String

    public init(blockedAccountIds: Set<String>, blockedCalendarIds: Set<String>, mirrorPath: String) {
        self.blockedAccountIds = blockedAccountIds
        self.blockedCalendarIds = blockedCalendarIds
        self.mirrorPath = mirrorPath
    }

    public static var defaultMirrorPath: String {
        NSHomeDirectory() + "/Library/Application Support/macos-calendar-mcp/events.sqlite"
    }

    public static func parse(arguments: [String], environment: [String: String]) throws -> Settings {
        var settings = Settings(
            blockedAccountIds: commaSeparated(environment["MACOS_CALENDAR_BLOCKED_ACCOUNTS"]),
            blockedCalendarIds: commaSeparated(environment["MACOS_CALENDAR_BLOCKED_CALENDARS"]),
            mirrorPath: defaultMirrorPath
        )
        var remaining = ArraySlice(arguments.dropFirst())
        while let flag = remaining.popFirst() {
            guard let value = remaining.popFirst() else { throw SettingsError.missingValue(flag) }
            switch flag {
            case "--block-account": settings.blockedAccountIds.insert(value)
            case "--block-calendar": settings.blockedCalendarIds.insert(value)
            case "--mirror": settings.mirrorPath = value
            default: throw SettingsError.unknownFlag(flag)
            }
        }
        return settings
    }

    private static func commaSeparated(_ raw: String?) -> Set<String> {
        let parts = (raw ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return Set(parts.filter { !$0.isEmpty })
    }
}

public enum SettingsError: Error, Equatable, CustomStringConvertible {
    case missingValue(String)
    case unknownFlag(String)

    public var description: String {
        switch self {
        case .missingValue(let flag): "\(flag) needs a value"
        case .unknownFlag(let flag): "Unknown option \(flag). Options: --block-account <id>, --block-calendar <id>, --mirror <path>"
        }
    }
}
