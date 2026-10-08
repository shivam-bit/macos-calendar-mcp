import Foundation
import MCP
import Testing
@testable import MacOSCalendarMCP

@Suite("Arguments")
struct ArgumentsTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    func context(events: [Event]) -> ToolContext {
        ToolContext(
            source: FakeCalendarSource(calendars: [makeCalendar(id: "work", accountId: "icloud")], events: events),
            access: CalendarAccess(settings: Settings(blockedAccountIds: [], blockedCalendarIds: [], mirrorPath: "")),
            mirror: unavailableMirror()
        )
    }

    func listArgs(limit: Int) -> Arguments {
        Arguments([
            "start": .string(Dates.format(now.addingTimeInterval(-60))),
            "end": .string(Dates.format(now.addingTimeInterval(3600))),
            "limit": .int(limit),
        ])
    }

    @Test("a wrong-typed string says it must be a string")
    func wrongTypedString() async {
        await #expect(throws: ToolError.invalidInput("start must be a string")) {
            try await ListEvents.definition.run(Arguments(["start": 5, "end": "2026-10-09"]), context(events: []))
        }
    }

    @Test("a null string counts as absent")
    func nullString() throws {
        #expect(try Arguments(["note": .null]).optionalString("note") == nil)
    }

    @Test("a wrong-typed bool is rejected")
    func wrongTypedBool() {
        #expect(throws: ToolError.invalidInput("flag must be true or false")) {
            try Arguments(["flag": "true"]).optionalBool("flag")
        }
    }

    @Test("a list with a non-string element is rejected")
    func mixedList() async {
        let args: [String: Value] = ["start": "2026-10-08", "end": "2026-10-09", "calendarIds": ["work", 5]]
        await #expect(throws: ToolError.invalidInput("calendarIds must be a list of strings")) {
            try await ListEvents.definition.run(Arguments(args), context(events: []))
        }
    }

    @Test("a limit of zero is clamped to one")
    func zeroLimit() async throws {
        let events = (0..<3).map { makeEvent(externalId: "e\($0)", start: now.addingTimeInterval(Double($0) * 60), calendarId: "work") }
        let output = try await ListEvents.definition.run(listArgs(limit: 0), context(events: events))
        let list = try JSONDecoder().decode(EventList.self, from: JSONEncoder().encode(output))
        #expect(list.events.count == 1 && list.truncated)
    }

    @Test("exactly limit events is not truncated")
    func exactLimit() async throws {
        let events = (0..<2).map { makeEvent(externalId: "e\($0)", start: now.addingTimeInterval(Double($0) * 60), calendarId: "work") }
        let output = try await ListEvents.definition.run(listArgs(limit: 2), context(events: events))
        let list = try JSONDecoder().decode(EventList.self, from: JSONEncoder().encode(output))
        #expect(list.events.count == 2 && !list.truncated)
    }

    @Test("null counts as absent for ints and string lists")
    func nullIntAndStrings() throws {
        let args = Arguments(["n": .null, "list": .null])
        #expect(try args.optionalInt("n") == nil)
        #expect(try args.optionalStrings("list") == nil)
    }

    @Test("a whole-number double is an int, a fractional one is rejected")
    func doubleInt() throws {
        #expect(try Arguments(["n": .double(50.0)]).optionalInt("n") == 50)
        #expect(throws: ToolError.invalidInput("n must be a whole number")) {
            try Arguments(["n": .double(50.5)]).optionalInt("n")
        }
    }
}
