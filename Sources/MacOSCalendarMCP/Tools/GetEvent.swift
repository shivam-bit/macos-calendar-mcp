import MCP

enum GetEvent {
    static let definition = ToolDefinition(
        tool: Tool(
            name: "get_event",
            description: "Get one event by its id, as returned by list_events or search_events.",
            inputSchema: Schema.object(["id": Schema.string("Event id")], required: ["id"])
        ),
        run: { args, context in
            let visible = await context.visibleCalendars()
            let matches = await context.source.matches(id: try args.string("id"), among: visible)
            return try EventID.pick(matches, editableCalendarIds: [], forWrite: false)
        }
    )
}
