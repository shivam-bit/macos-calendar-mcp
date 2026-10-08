import Foundation
import MCP
import Testing
@testable import MacOSCalendarMCP

@Suite("Read tools")
struct ReadToolTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let work = makeCalendar(id: "work", accountId: "icloud")
    let personal = makeCalendar(id: "personal", accountId: "google")

    func context(blockedAccounts: Set<String> = [], events: [Event]) -> ToolContext {
        ToolContext(
            source: FakeCalendarSource(calendars: [work, personal], events: events),
            access: CalendarAccess(settings: Settings(blockedAccountIds: blockedAccounts, blockedCalendarIds: [], mirrorPath: "")),
            mirror: unavailableMirror(),
            now: { [now] in now }
        )
    }

    func run<T: Decodable>(_ definition: ToolDefinition, _ args: [String: Value], _ context: ToolContext, decodedAs: T.Type) async throws -> T {
        let output = try await definition.run(Arguments(args), context)
        return try JSONDecoder().decode(T.self, from: JSONEncoder().encode(output))
    }

    @Test("list_calendars hides blocked accounts")
    func listCalendarsHidesBlocked() async throws {
        let calendars = try await run(ListCalendars.definition, [:], context(blockedAccounts: ["google"], events: []), decodedAs: [EventCalendar].self)
        #expect(calendars.map(\.id) == ["work"])
    }

    @Test("list_events returns events in range from visible calendars only")
    func listEvents() async throws {
        let visible = makeEvent(externalId: "a", start: now, calendarId: "work")
        let hidden = makeEvent(externalId: "b", start: now, calendarId: "personal")
        let args: [String: Value] = ["start": .string(Dates.format(now.addingTimeInterval(-60))), "end": .string(Dates.format(now.addingTimeInterval(3600)))]
        let list = try await run(ListEvents.definition, args, context(blockedAccounts: ["google"], events: [visible, hidden]), decodedAs: EventList.self)
        #expect(list.events == [visible])
        #expect(!list.truncated)
    }

    @Test("list_events with a hidden calendar id says not found")
    func listEventsHiddenCalendar() async {
        let args: [String: Value] = ["start": "2026-10-08", "end": "2026-10-09", "calendarIds": ["personal"]]
        await #expect(throws: ToolError.notFound("calendar")) {
            try await ListEvents.definition.run(Arguments(args), context(blockedAccounts: ["google"], events: []))
        }
    }

    @Test("list_events marks truncation at the limit")
    func listEventsTruncates() async throws {
        let events = (0..<3).map { makeEvent(externalId: "e\($0)", start: now.addingTimeInterval(Double($0) * 60)) }
        let args: [String: Value] = ["start": .string(Dates.format(now.addingTimeInterval(-60))), "end": .string(Dates.format(now.addingTimeInterval(3600))), "limit": 2]
        let list = try await run(ListEvents.definition, args, context(events: events), decodedAs: EventList.self)
        #expect(list.events.count == 2 && list.truncated)
    }

    @Test("list_events rejects an end before the start")
    func listEventsBadRange() async {
        let args: [String: Value] = ["start": "2026-10-09", "end": "2026-10-08"]
        await #expect(throws: ToolError.invalidInput("end must be after start")) {
            try await ListEvents.definition.run(Arguments(args), context(events: []))
        }
    }

    @Test("get_event finds a visible event by id")
    func getEvent() async throws {
        let event = makeEvent(start: now, calendarId: "work")
        let found = try await run(GetEvent.definition, ["id": .string(event.id)], context(events: [event]), decodedAs: Event.self)
        #expect(found == event)
    }

    @Test("get_event on a blocked calendar's event is not found")
    func getEventHidden() async {
        let event = makeEvent(start: now, calendarId: "personal")
        await #expect(throws: ToolError.notFound("event")) {
            try await GetEvent.definition.run(Arguments(["id": .string(event.id)]), context(blockedAccounts: ["google"], events: [event]))
        }
    }

    @Test("get_event with a garbage id is not found")
    func getEventWithGarbageIdIsNotFound() async {
        for garbage in ["nonsense", "x:", ":123", "🙂:999"] {
            await #expect(throws: ToolError.notFound("event")) {
                try await GetEvent.definition.run(Arguments(["id": .string(garbage)]), context(events: []))
            }
        }
    }

    @Test("search_events matches title, location and notes, case-insensitively")
    func search() async throws {
        let byTitle = makeEvent(externalId: "t", start: now, title: "Design Review")
        let byNotes = makeEvent(externalId: "n", start: now, title: "Sync", notes: "bring the design doc")
        let other = makeEvent(externalId: "o", start: now, title: "Lunch")
        let args: [String: Value] = ["text": "DESIGN", "start": .string(Dates.format(now.addingTimeInterval(-60))), "end": .string(Dates.format(now.addingTimeInterval(3600)))]
        let list = try await run(SearchEvents.definition, args, context(events: [byTitle, byNotes, other]), decodedAs: EventList.self)
        #expect(Set(list.events.map(\.id)) == [byTitle.id, byNotes.id])
    }

    @Test("list_events sorts by start and truncation keeps the earliest")
    func listEventsSortedBeforeTruncation() async throws {
        let late = makeEvent(externalId: "c", start: now.addingTimeInterval(180))
        let early = makeEvent(externalId: "a", start: now.addingTimeInterval(60))
        let middle = makeEvent(externalId: "b", start: now.addingTimeInterval(120))
        let args: [String: Value] = ["start": .string(Dates.format(now)), "end": .string(Dates.format(now.addingTimeInterval(3600))), "limit": 2]
        let list = try await run(ListEvents.definition, args, context(events: [late, early, middle]), decodedAs: EventList.self)
        #expect(list.events == [early, middle] && list.truncated)
    }
}
