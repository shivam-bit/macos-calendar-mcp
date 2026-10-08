import Foundation
import MCP
import Testing
@testable import MacOSCalendarMCP

@Suite("Server")
struct ServerTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let work = makeCalendar(id: "work")

    func context(_ source: FakeCalendarSource, mirror: MirrorProvider = unavailableMirror()) -> ToolContext {
        ToolContext(source: source,
                    access: CalendarAccess(settings: Settings(blockedAccountIds: [], blockedCalendarIds: [], mirrorPath: "")),
                    mirror: mirror, now: { [now] in now })
    }

    func text(_ result: CallTool.Result) -> String {
        guard case .text(let text, _, _) = result.content.first else { return "" }
        return text
    }

    @Test("the server lists all eight tools")
    func toolNames() {
        #expect(CalendarServer.tools.map(\.tool.name) == [
            "list_calendars", "list_events", "get_event", "search_events",
            "create_event", "update_event", "delete_event", "get_changes",
        ])
    }

    @Test("a tool error becomes an error result with error and hint")
    func errorShape() async throws {
        let result = await CalendarServer.call(name: "get_event", arguments: ["id": "missing"], context: context(FakeCalendarSource(calendars: [work], events: [])))
        #expect(result.isError == true)
        let body = try JSONDecoder().decode([String: String].self, from: Data(text(result).utf8))
        #expect(body["error"] == "Event not found.")
        #expect(body["hint"] != nil)
    }

    @Test("denied calendar access fails every tool with a hint")
    func accessDenied() async {
        let source = FakeCalendarSource(calendars: [work], events: [], permission: .denied)
        let result = await CalendarServer.call(name: "list_calendars", arguments: [:], context: context(source))
        #expect(result.isError == true)
        #expect(text(result).contains("Privacy & Security"))
    }

    @Test("undecided access is requested on first call")
    func requestsAccess() async {
        let source = FakeCalendarSource(calendars: [work], events: [], permission: .notDetermined, grantOnRequest: true)
        let result = await CalendarServer.call(name: "list_calendars", arguments: [:], context: context(source))
        #expect(result.isError == false)
    }

    @Test("an unknown tool is an error result")
    func unknownTool() async {
        let result = await CalendarServer.call(name: "nope", arguments: [:], context: context(FakeCalendarSource(calendars: [], events: [])))
        #expect(result.isError == true)
    }

    @Test("get_changes refreshes the mirror and returns a page")
    func getChanges() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("srv-\(UUID().uuidString).sqlite").path
        let event = makeEvent(start: now)
        let source = FakeCalendarSource(calendars: [work], events: [event])
        let result = await CalendarServer.call(name: "get_changes", arguments: ["after": 0], context: context(source, mirror: MirrorProvider(path: path)))
        #expect(result.isError == false)
        #expect(text(result).contains(event.id))
        #expect(text(result).contains("\"next\":1"))
    }

    @Test("list_events works when the mirror is unavailable")
    func listEventsWorksWhenMirrorUnavailable() async {
        let source = FakeCalendarSource(calendars: [work], events: [makeEvent(start: now)])
        let args: [String: Value] = ["start": .string(Dates.format(now.addingTimeInterval(-60))), "end": .string(Dates.format(now.addingTimeInterval(60)))]
        #expect(await CalendarServer.call(name: "list_events", arguments: args, context: context(source)).isError == false)
        #expect(await CalendarServer.call(name: "get_changes", arguments: ["after": 0], context: context(source)).isError == true)
    }

    @Test("get_changes with no calendars from EventKit leaves the mirror alone")
    func emptyCalendarsSkipRefresh() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("srv-\(UUID().uuidString).sqlite").path
        let provider = MirrorProvider(path: path)
        let populated = FakeCalendarSource(calendars: [work], events: [makeEvent(start: now)])
        _ = await CalendarServer.call(name: "get_changes", arguments: ["after": 0], context: context(populated, mirror: provider))
        let empty = FakeCalendarSource(calendars: [], events: [])
        let result = await CalendarServer.call(name: "get_changes", arguments: ["after": 0], context: context(empty, mirror: provider))
        #expect(result.isError == false)
        #expect(text(result).contains("\"next\":1"))
    }
}
