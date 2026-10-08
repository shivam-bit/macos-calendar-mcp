import MCP

struct Deleted: Codable, Equatable, Sendable {
    let deleted: String
}

enum DeleteEvent {
    static let definition = ToolDefinition(
        tool: Tool(
            name: "delete_event",
            description: "Delete one occurrence of an event.",
            inputSchema: Schema.object(["id": Schema.string("Event id")], required: ["id"])
        ),
        run: { args, context in
            let id = try args.string("id")
            try await context.source.delete(id: id, among: await context.visibleCalendars())
            return Deleted(deleted: id)
        }
    )
}
