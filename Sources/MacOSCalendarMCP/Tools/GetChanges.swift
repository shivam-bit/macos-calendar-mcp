import MCP

struct ChangesReply: Codable, Equatable, Sendable {
    let changes: [EventChange]?
    let next: Int64?
    let hasMore: Bool?
    let reset: Bool?
}

enum GetChanges {
    static let definition = ToolDefinition(
        tool: Tool(
            name: "get_changes",
            description: "For sync clients: events added, changed, or deleted after an offset. Start with after = 0, then pass back next. A change's identity is (id, calendarId): the same id can appear in several calendars.",
            inputSchema: Schema.object([
                "after": Schema.integer("Offset from the previous reply's next. 0 returns every current event."),
                "limit": Schema.integer("Most changes to return. Default 500, at most 2000."),
            ], required: ["after"])
        ),
        run: { args, context in
            let mirror = try await context.mirror.mirror()
            guard let after = try args.optionalInt("after"), after >= 0 else { throw ToolError.invalidInput("after must be 0 or more") }
            let now = context.now()
            let window = EventMirror.window(now: now)
            // Reads every calendar: the mirror is shared, and mirror.changes applies this server's block rule
            let readAt = context.now()
            let calendars = await context.source.calendars()
            // EventKit can return no calendars for a moment while access is granted; refreshing then would tombstone every row
            if !calendars.isEmpty {
                let events = await context.source.events(among: calendars, from: window.start, to: window.end)
                try await mirror.refresh(calendars: calendars, events: events, now: now, readAt: readAt)
            }
            let limit = try ListEvents.limit(args, default: 500, max: 2000)
            switch try await mirror.changes(after: Int64(after), limit: limit, access: context.access) {
            case .reset:
                return ChangesReply(changes: nil, next: nil, hasMore: nil, reset: true)
            case .page(let changes, let next, let hasMore):
                return ChangesReply(changes: changes, next: next, hasMore: hasMore, reset: nil)
            }
        }
    )
}
