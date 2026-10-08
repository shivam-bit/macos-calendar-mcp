import MCP

enum UpdateEvent {
    static let definition = ToolDefinition(
        tool: Tool(
            name: "update_event",
            description: "Change one occurrence of an event. Returns the event; its id changes when the start changes.",
            inputSchema: Schema.object([
                "id": Schema.string("Event id"),
                "title": Schema.string("New title"),
                "start": Schema.string("New start. \(Schema.date)"),
                "end": Schema.string("New end. \(Schema.date)"),
                "location": Schema.string("New location"),
                "notes": Schema.string("New notes"),
            ], required: ["id"])
        ),
        run: { args, context in
            let changes = EventChanges(
                title: try args.optionalString("title"), start: try args.optionalDate("start"), end: try args.optionalDate("end"),
                location: try args.optionalString("location"), notes: try args.optionalString("notes")
            )
            guard !changes.isEmpty else { throw ToolError.invalidInput("Give at least one field to change") }
            return try await context.source.update(id: try args.string("id"), changes: changes, among: await context.visibleCalendars())
        }
    )
}
