import MCP

enum SearchEvents {
    static let definition = ToolDefinition(
        tool: Tool(
            name: "search_events",
            description: "Find events that overlap the range from start to end whose title, location, or notes contain some text.",
            inputSchema: Schema.object([
                "text": Schema.string("Text to look for. Case does not matter."),
                "start": Schema.string("Start of the range. \(Schema.date)"),
                "end": Schema.string("End of the range. \(Schema.date)"),
                "limit": Schema.integer("Most events to return. Default 50, at most 500."),
            ], required: ["text", "start", "end"])
        ),
        run: { args, context in
            let text = try args.string("text")
            let range = try ListEvents.dateRange(args)
            let events = await context.source.events(among: await context.visibleCalendars(), from: range.start, to: range.end)
            let found = events.filter { event in
                [event.title, event.location, event.notes].contains { $0?.localizedCaseInsensitiveContains(text) == true }
            }
            return EventList(found, limit: try ListEvents.limit(args, default: 50, max: 500))
        }
    )
}
