import Foundation
import MCP

public struct ToolContext: Sendable {
    public let source: any CalendarSource
    public let access: CalendarAccess
    public let mirror: MirrorProvider
    public let now: @Sendable () -> Date

    public init(source: any CalendarSource, access: CalendarAccess, mirror: MirrorProvider, now: @escaping @Sendable () -> Date = Date.init) {
        self.source = source
        self.access = access
        self.mirror = mirror
        self.now = now
    }

    func visibleCalendars() async -> [EventCalendar] {
        access.visible(await source.calendars())
    }
}

public struct ToolDefinition: Sendable {
    public let tool: Tool
    public let run: @Sendable (Arguments, ToolContext) async throws -> any Encodable & Sendable
}

struct EventList: Codable, Equatable, Sendable {
    let events: [Event]
    let truncated: Bool

    init(_ events: [Event], limit: Int) {
        self.events = Array(events.prefix(limit))
        truncated = events.count > limit
    }
}

enum Schema {
    static func object(_ properties: [String: Value], required: [String] = []) -> Value {
        ["type": "object", "properties": .object(properties), "required": .array(required.map(Value.string))]
    }

    static func string(_ description: String) -> Value { ["type": "string", "description": .string(description)] }
    static func integer(_ description: String) -> Value { ["type": "integer", "description": .string(description)] }
    static func boolean(_ description: String) -> Value { ["type": "boolean", "description": .string(description)] }
    static func strings(_ description: String) -> Value {
        ["type": "array", "items": ["type": "string"], "description": .string(description)]
    }

    static let date = "ISO-8601, e.g. 2026-10-08T13:00:00. Without a timezone, the Mac's local time is used."
}
