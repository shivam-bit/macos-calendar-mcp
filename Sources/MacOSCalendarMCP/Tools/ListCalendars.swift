import MCP

enum ListCalendars {
    static let definition = ToolDefinition(
        tool: Tool(
            name: "list_calendars",
            description: "List the calendars you can use, with their ids, accounts, and whether they can be edited.",
            inputSchema: Schema.object([:])
        ),
        run: { _, context in await context.visibleCalendars() }
    )
}
