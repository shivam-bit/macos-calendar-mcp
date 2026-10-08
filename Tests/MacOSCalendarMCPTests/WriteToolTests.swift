import Foundation
import MCP
import Testing
@testable import MacOSCalendarMCP

@Suite("Write tools")
struct WriteToolTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let work = EventCalendar(id: "work", name: "Work", account: Account(id: "icloud", name: "iCloud", type: "calDAV"),
                             color: nil, editable: true, subscribed: false, isDefault: true, type: "calDAV")
    let holidays = makeCalendar(id: "holidays", accountId: "google", editable: false)

    func context(_ source: FakeCalendarSource, blockedAccounts: Set<String> = []) -> ToolContext {
        ToolContext(source: source,
                    access: CalendarAccess(settings: Settings(blockedAccountIds: blockedAccounts, blockedCalendarIds: [], mirrorPath: "")),
                    mirror: unavailableMirror(), now: { [now] in now })
    }

    func decode<T: Decodable>(_ output: any Encodable & Sendable, decodedAs: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(output))
    }

    @Test("create without a calendar uses the default calendar")
    func createDefault() async throws {
        let source = FakeCalendarSource(calendars: [work, holidays], events: [])
        let args: [String: Value] = ["title": "Lunch", "start": .string(Dates.format(now)), "end": .string(Dates.format(now.addingTimeInterval(3600)))]
        let created = try decode(try await CreateEvent.definition.run(Arguments(args), context(source)), decodedAs: Event.self)
        #expect(created.calendarId == "work" && created.title == "Lunch")
        #expect(await source.storedEvents.count == 1)
    }

    @Test("create without a calendar fails clearly when there is no default calendar")
    func createWithoutDefault() async {
        let source = FakeCalendarSource(calendars: [holidays], events: [])
        let args: [String: Value] = ["title": "x", "start": .string(Dates.format(now)), "end": .string(Dates.format(now.addingTimeInterval(60)))]
        await #expect(throws: ToolError.invalidInput("No default calendar is available; pass calendarId from list_calendars")) {
            try await CreateEvent.definition.run(Arguments(args), context(source))
        }
    }

    @Test("create in a read-only calendar is refused")
    func createReadOnly() async {
        let source = FakeCalendarSource(calendars: [work, holidays], events: [])
        let args: [String: Value] = ["title": "x", "start": .string(Dates.format(now)), "end": .string(Dates.format(now.addingTimeInterval(60))), "calendarId": "holidays"]
        await #expect(throws: ToolError.readOnly("holidays")) {
            try await CreateEvent.definition.run(Arguments(args), context(source))
        }
    }

    @Test("create in a blocked calendar says not found")
    func createBlocked() async {
        let source = FakeCalendarSource(calendars: [work, holidays], events: [])
        let args: [String: Value] = ["title": "x", "start": .string(Dates.format(now)), "end": .string(Dates.format(now.addingTimeInterval(60))), "calendarId": "work"]
        await #expect(throws: ToolError.notFound("calendar")) {
            try await CreateEvent.definition.run(Arguments(args), context(source, blockedAccounts: ["icloud"]))
        }
    }

    @Test("create rejects an end before the start")
    func createRejectsEndBeforeStart() async {
        let source = FakeCalendarSource(calendars: [work], events: [])
        let args: [String: Value] = ["title": "x", "start": .string(Dates.format(now)), "end": .string(Dates.format(now.addingTimeInterval(-60)))]
        await #expect(throws: ToolError.invalidInput("end must be after start")) {
            try await CreateEvent.definition.run(Arguments(args), context(source))
        }
    }

    @Test("update changes the fields given and returns the new id when the start moves")
    func updateMovesStart() async throws {
        let original = makeEvent(externalId: "u", start: now, calendarId: "work", title: "Old")
        let source = FakeCalendarSource(calendars: [work], events: [original])
        let newStart = now.addingTimeInterval(3600)
        let args: [String: Value] = ["id": .string(original.id), "title": "New", "start": .string(Dates.format(newStart)), "end": .string(Dates.format(newStart.addingTimeInterval(1800)))]
        let updated = try decode(try await UpdateEvent.definition.run(Arguments(args), context(source)), decodedAs: Event.self)
        #expect(updated.title == "New")
        #expect(updated.id != original.id)
        #expect(updated.id == EventID.format(externalId: "u", localId: "", recurring: false, start: newStart))
    }

    @Test("update with no changes is an input error")
    func updateNothing() async {
        let original = makeEvent(start: now)
        let source = FakeCalendarSource(calendars: [work], events: [original])
        await #expect(throws: ToolError.invalidInput("Give at least one field to change")) {
            try await UpdateEvent.definition.run(Arguments(["id": .string(original.id)]), context(source))
        }
    }

    @Test("delete removes the event in the editable calendar")
    func deleteEditable() async throws {
        let original = makeEvent(start: now, calendarId: "work")
        let source = FakeCalendarSource(calendars: [work], events: [original])
        let result = try decode(try await DeleteEvent.definition.run(Arguments(["id": .string(original.id)]), context(source)), decodedAs: Deleted.self)
        #expect(result == Deleted(deleted: original.id))
        #expect(await source.storedEvents.isEmpty)
    }

    @Test("delete of an event only in a read-only calendar is refused")
    func deleteReadOnly() async {
        let original = makeEvent(start: now, calendarId: "holidays")
        let source = FakeCalendarSource(calendars: [work, holidays], events: [original])
        await #expect(throws: ToolError.readOnly("holidays")) {
            try await DeleteEvent.definition.run(Arguments(["id": .string(original.id)]), context(source))
        }
    }
}
