import Foundation
import Testing
@testable import MacOSCalendarMCP

@Suite("EventMirror")
struct EventMirrorTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let work = makeCalendar(id: "work", accountId: "icloud")
    let gmail = makeCalendar(id: "gmail", accountId: "google")
    let openAccess = CalendarAccess(settings: Settings(blockedAccountIds: [], blockedCalendarIds: [], mirrorPath: ""))

    func tempPath() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("mirror-\(UUID().uuidString).sqlite").path
    }

    func page(_ result: ChangesPage) throws -> (changes: [EventChange], next: Int64, hasMore: Bool) {
        guard case .page(let changes, let next, let hasMore) = result else { throw ToolError.unavailable("expected a page") }
        return (changes, next, hasMore)
    }

    @Test("new events appear with increasing versions")
    func insert() async throws {
        let mirror = try EventMirror(path: tempPath())
        let first = makeEvent(externalId: "a", start: now)
        let second = makeEvent(externalId: "b", start: now.addingTimeInterval(3600))
        try await mirror.refresh(calendars: [work], events: [first, second], now: now, readAt: now)
        let result = try page(await mirror.changes(after: 0, limit: 10, access: openAccess))
        #expect(result.changes.map(\.id) == [first.id, second.id])
        #expect(result.changes.map(\.version) == [1, 2])
        #expect(result.next == 2)
        #expect(!result.hasMore)
    }

    @Test("an unchanged refresh adds no versions")
    func unchanged() async throws {
        let mirror = try EventMirror(path: tempPath())
        let event = makeEvent(start: now)
        try await mirror.refresh(calendars: [work], events: [event], now: now, readAt: now)
        try await mirror.refresh(calendars: [work], events: [event], now: now, readAt: now)
        #expect(try page(await mirror.changes(after: 1, limit: 10, access: openAccess)).changes.isEmpty)
    }

    @Test("an edit bumps the version")
    func edit() async throws {
        let mirror = try EventMirror(path: tempPath())
        try await mirror.refresh(calendars: [work], events: [makeEvent(start: now, title: "Old")], now: now, readAt: now)
        try await mirror.refresh(calendars: [work], events: [makeEvent(start: now, title: "New")], now: now, readAt: now)
        let result = try page(await mirror.changes(after: 1, limit: 10, access: openAccess))
        #expect(result.changes.count == 1)
        #expect(result.changes[0].event?.title == "New")
        #expect(result.changes[0].version == 2)
    }

    @Test("an event missing inside the window becomes a tombstone")
    func deleteInsideWindow() async throws {
        let mirror = try EventMirror(path: tempPath())
        let event = makeEvent(start: now.addingTimeInterval(86400))
        try await mirror.refresh(calendars: [work], events: [event], now: now, readAt: now)
        try await mirror.refresh(calendars: [work], events: [], now: now, readAt: now)
        let result = try page(await mirror.changes(after: 1, limit: 10, access: openAccess))
        #expect(result.changes == [EventChange(id: event.id, calendarId: "work", version: 2, deleted: true, event: nil)])
    }

    @Test("an event that ages out of the window leaves no tombstone")
    func ageOut() async throws {
        let mirror = try EventMirror(path: tempPath())
        let event = makeEvent(start: now.addingTimeInterval(-6 * 86400))
        try await mirror.refresh(calendars: [work], events: [event], now: now, readAt: now)
        let later = now.addingTimeInterval(2 * 86400)
        try await mirror.refresh(calendars: [work], events: [], now: later, readAt: later)
        #expect(try page(await mirror.changes(after: 1, limit: 10, access: openAccess)).changes.isEmpty)
    }

    @Test("blocked calendars and accounts are filtered on read, tombstones included")
    func filterOnRead() async throws {
        let mirror = try EventMirror(path: tempPath())
        let workEvent = makeEvent(externalId: "w", start: now, calendarId: "work")
        let gmailEvent = makeEvent(externalId: "g", start: now, calendarId: "gmail")
        try await mirror.refresh(calendars: [work, gmail], events: [workEvent, gmailEvent], now: now, readAt: now)
        let blockGoogle = CalendarAccess(settings: Settings(blockedAccountIds: ["google"], blockedCalendarIds: [], mirrorPath: ""))
        #expect(try page(await mirror.changes(after: 0, limit: 10, access: blockGoogle)).changes.map(\.id) == [workEvent.id])
        try await mirror.refresh(calendars: [work, gmail], events: [workEvent], now: now, readAt: now)
        #expect(try page(await mirror.changes(after: 2, limit: 10, access: blockGoogle)).changes.isEmpty)
    }

    @Test("the same event in two calendars is two rows")
    func sameEventTwoCalendars() async throws {
        let mirror = try EventMirror(path: tempPath())
        let inWork = makeEvent(externalId: "x", start: now, calendarId: "work")
        let inGmail = makeEvent(externalId: "x", start: now, calendarId: "gmail")
        try await mirror.refresh(calendars: [work, gmail], events: [inWork, inGmail], now: now, readAt: now)
        let result = try page(await mirror.changes(after: 0, limit: 10, access: openAccess))
        #expect(Set(result.changes.map(\.calendarId)) == ["work", "gmail"])
    }

    @Test("paging returns hasMore and a resumable offset")
    func paging() async throws {
        let mirror = try EventMirror(path: tempPath())
        let events = (0..<3).map { makeEvent(externalId: "e\($0)", start: now.addingTimeInterval(Double($0) * 3600)) }
        try await mirror.refresh(calendars: [work], events: events, now: now, readAt: now)
        let first = try page(await mirror.changes(after: 0, limit: 2, access: openAccess))
        #expect(first.changes.count == 2 && first.hasMore && first.next == 2)
        let second = try page(await mirror.changes(after: first.next, limit: 2, access: openAccess))
        #expect(second.changes.count == 1 && !second.hasMore && second.next == 3)
    }

    @Test("after 0 skips tombstones")
    func snapshotSkipsTombstones() async throws {
        let mirror = try EventMirror(path: tempPath())
        let kept = makeEvent(externalId: "k", start: now)
        let gone = makeEvent(externalId: "g", start: now)
        try await mirror.refresh(calendars: [work], events: [kept, gone], now: now, readAt: now)
        try await mirror.refresh(calendars: [work], events: [kept], now: now, readAt: now)
        #expect(try page(await mirror.changes(after: 0, limit: 10, access: openAccess)).changes.map(\.id) == [kept.id])
    }

    @Test("an offset older than pruned tombstones gets a reset")
    func resetAfterPrune() async throws {
        let mirror = try EventMirror(path: tempPath())
        let event = makeEvent(start: now.addingTimeInterval(86400))
        try await mirror.refresh(calendars: [work], events: [event], now: now, readAt: now)
        try await mirror.refresh(calendars: [work], events: [], now: now, readAt: now)
        try await mirror.refresh(calendars: [work], events: [], now: now.addingTimeInterval(31 * 86400), readAt: now.addingTimeInterval(31 * 86400))
        #expect(try await mirror.changes(after: 1, limit: 10, access: openAccess) == .reset)
        #expect(try page(await mirror.changes(after: 2, limit: 10, access: openAccess)).changes.isEmpty)
    }

    @Test("two mirrors on one file keep versions unique")
    func concurrentRefreshesKeepVersionsUnique() async throws {
        let path = tempPath()
        let first = try EventMirror(path: path)
        let second = try EventMirror(path: path)
        let events = (0..<50).map { makeEvent(externalId: "c\($0)", start: now.addingTimeInterval(Double($0) * 60)) }
        async let a: Void = first.refresh(calendars: [work], events: Array(events[..<30]), now: now, readAt: now)
        async let b: Void = second.refresh(calendars: [work], events: Array(events[20...]), now: now, readAt: now)
        _ = try await (a, b)
        let all = try page(await first.changes(after: 0, limit: 100, access: openAccess)).changes
        #expect(Set(all.map(\.version)).count == all.count)
    }

    @Test("an offset beyond the mirror's version gets a reset")
    func resetWhenAfterBeyondVersion() async throws {
        let mirror = try EventMirror(path: tempPath())
        try await mirror.refresh(calendars: [work], events: [makeEvent(start: now)], now: now, readAt: now)
        #expect(try await mirror.changes(after: 5, limit: 10, access: openAccess) == .reset)
        #expect(try await mirror.changes(after: 1, limit: 10, access: openAccess) != .reset)
    }

    @Test("an older read cannot overwrite a newer one")
    func staleSnapshotIsDropped() async throws {
        let mirror = try EventMirror(path: tempPath())
        let t1 = now
        let t0 = now.addingTimeInterval(-10)
        try await mirror.refresh(calendars: [work], events: [makeEvent(start: now, title: "New")], now: now, readAt: t1)
        try await mirror.refresh(calendars: [work], events: [makeEvent(start: now, title: "Old")], now: now, readAt: t0)
        let result = try page(await mirror.changes(after: 0, limit: 10, access: openAccess))
        #expect(result.changes.map { $0.event?.title } == ["New"])
        #expect(result.next == 1)
    }

    @Test("a move between calendars deletes the old row at a lower version than it upserts the new one")
    func moveOrdersDeleteBeforeUpsert() async throws {
        let mirror = try EventMirror(path: tempPath())
        try await mirror.refresh(calendars: [work, gmail], events: [makeEvent(externalId: "m", start: now, calendarId: "work")], now: now, readAt: now)
        let moved = makeEvent(externalId: "m", start: now, calendarId: "gmail")
        try await mirror.refresh(calendars: [work, gmail], events: [moved], now: now, readAt: now)
        let changes = try page(await mirror.changes(after: 1, limit: 10, access: openAccess)).changes
        #expect(changes.map(\.calendarId) == ["work", "gmail"])
        #expect(changes.map(\.deleted) == [true, false])
        #expect(changes[0].version < changes[1].version)
    }

    @Test("the provider retries opening after a failure")
    func providerRetries() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("provider-\(UUID().uuidString)")
        try Data().write(to: directory)
        let provider = MirrorProvider(path: directory.appendingPathComponent("sub/events.sqlite").path)
        await #expect(throws: ToolError.self) { _ = try await provider.mirror() }
        try FileManager.default.removeItem(at: directory)
        let first = try await provider.mirror()
        let second = try await provider.mirror()
        #expect(first === second)
    }
}
