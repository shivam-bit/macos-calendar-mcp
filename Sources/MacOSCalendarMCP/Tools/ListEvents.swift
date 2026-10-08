import Foundation
import MCP

enum ListEvents {
    static let maxRange: TimeInterval = 366 * 86400

    static let definition = ToolDefinition(
        tool: Tool(
            name: "list_events",
            description: "List events that overlap the range from start to end, optionally only from some calendars.",
            inputSchema: Schema.object([
                "start": Schema.string("Start of the range. \(Schema.date)"),
                "end": Schema.string("End of the range. \(Schema.date)"),
                "calendarIds": Schema.strings("Only these calendars, by id from list_calendars. Omit for all."),
                "limit": Schema.integer("Most events to return. Default 200, at most 1000."),
            ], required: ["start", "end"])
        ),
        run: { args, context in
            let range = try dateRange(args)
            let calendars = try await scopedCalendars(args, context)
            let events = await context.source.events(among: calendars, from: range.start, to: range.end)
            return EventList(events, limit: try limit(args, default: 200, max: 1000))
        }
    )

    static func dateRange(_ args: Arguments) throws -> (start: Date, end: Date) {
        let start = try args.date("start")
        let end = try args.date("end")
        guard end > start else { throw ToolError.invalidInput("end must be after start") }
        guard end.timeIntervalSince(start) <= maxRange else { throw ToolError.invalidInput("The range can be at most 366 days") }
        return (start, end)
    }

    static func scopedCalendars(_ args: Arguments, _ context: ToolContext) async throws -> [EventCalendar] {
        let visible = await context.visibleCalendars()
        guard let requestedIds = try args.optionalStrings("calendarIds") else { return visible }
        let visibleIds = Set(visible.map(\.id))
        guard requestedIds.allSatisfy(visibleIds.contains) else { throw ToolError.notFound("calendar") }
        return visible.filter { requestedIds.contains($0.id) }
    }

    static func limit(_ args: Arguments, default defaultLimit: Int, max maxLimit: Int) throws -> Int {
        min(max(try args.optionalInt("limit") ?? defaultLimit, 1), maxLimit)
    }
}
