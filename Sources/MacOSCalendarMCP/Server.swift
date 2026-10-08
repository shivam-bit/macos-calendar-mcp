import Foundation
import MCP

public enum CalendarServer {
    public static let tools: [ToolDefinition] = [
        ListCalendars.definition, ListEvents.definition, GetEvent.definition, SearchEvents.definition,
        CreateEvent.definition, UpdateEvent.definition, DeleteEvent.definition, GetChanges.definition,
    ]

    public static func start(context: ToolContext) async throws {
        let server = Server(name: "macos-calendar-mcp", version: "0.1.0", capabilities: .init(tools: .init(listChanged: false)))
        await server.withMethodHandler(ListTools.self) { _ in .init(tools: tools.map(\.tool)) }
        await server.withMethodHandler(CallTool.self) { params in
            await call(name: params.name, arguments: params.arguments ?? [:], context: context)
        }
        try await server.start(transport: StdioTransport())
        await server.waitUntilCompleted()
    }

    public static func call(name: String, arguments: [String: Value], context: ToolContext) async -> CallTool.Result {
        guard let definition = tools.first(where: { $0.tool.name == name }) else {
            return failure(.invalidInput("Unknown tool \(name)"))
        }
        do {
            try await ensureAccess(context.source)
            let output = try await definition.run(Arguments(arguments), context)
            return .init(content: [.text(text: try json(output), annotations: nil, _meta: nil)], isError: false)
        } catch let error as ToolError {
            if case .unavailable(let reason) = error { log("\(name) failed: \(reason)") }
            return failure(error)
        } catch {
            log("\(name) failed: \(error)")
            return failure(.unavailable("Something went wrong."))
        }
    }

    private static func ensureAccess(_ source: any CalendarSource) async throws {
        switch await source.permission() {
        case .granted: return
        case .notDetermined: guard await source.requestAccess() else { throw ToolError.accessDenied }
        case .denied: throw ToolError.accessDenied
        }
    }

    private static func failure(_ error: ToolError) -> CallTool.Result {
        let body = (try? json(["error": error.error, "hint": error.hint])) ?? error.error
        return .init(content: [.text(text: body, annotations: nil, _meta: nil)], isError: true)
    }

    private static func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    static func log(_ message: String) {
        FileHandle.standardError.write(Data("[macos-calendar-mcp] \(message)\n".utf8))
    }
}
