import Foundation
@testable import MacOSCalendarMCP

actor FakeCalendarSource: CalendarSource {
    private(set) var storedCalendars: [EventCalendar]
    private(set) var storedEvents: [Event]
    private var currentPermission: CalendarPermission
    private let grantOnRequest: Bool
    private var createdCount = 0

    init(calendars: [EventCalendar], events: [Event], permission: CalendarPermission = .granted, grantOnRequest: Bool = true) {
        storedCalendars = calendars
        storedEvents = events
        currentPermission = permission
        self.grantOnRequest = grantOnRequest
    }

    func permission() -> CalendarPermission { currentPermission }

    func requestAccess() -> Bool {
        currentPermission = grantOnRequest ? .granted : .denied
        return grantOnRequest
    }

    func calendars() -> [EventCalendar] { storedCalendars }

    func events(among calendars: [EventCalendar], from: Date, to: Date) -> [Event] {
        let ids = Set(calendars.map(\.id))
        return storedEvents.filter { event in
            guard ids.contains(event.calendarId), let start = Dates.parse(event.start) else { return false }
            return start >= from && start < to
        }.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    func matches(id: String, among calendars: [EventCalendar]) -> [Event] {
        let ids = Set(calendars.map(\.id))
        return storedEvents.filter { $0.id == id && ids.contains($0.calendarId) }
    }

    func create(_ draft: EventDraft, among calendars: [EventCalendar]) throws -> Event {
        guard let targetId = draft.calendarId ?? calendars.first(where: \.isDefault)?.id else {
            throw ToolError.invalidInput("No default calendar is available; pass calendarId from list_calendars")
        }
        let target = try writableCalendar(targetId, among: calendars)
        createdCount += 1
        let event = Event(
            id: EventID.format(externalId: "fake-\(createdCount)", localId: "", recurring: false, start: draft.start),
            start: Dates.format(draft.start), end: Dates.format(draft.end), allDay: draft.allDay, title: draft.title,
            calendarId: target.id, calendarName: target.name, location: draft.location, notes: draft.notes,
            url: draft.url?.absoluteString, status: "confirmed", organizer: nil, attendees: [], recurring: false,
            externalId: nil, seriesId: nil, conferenceUrl: nil, created: nil, updated: nil
        )
        storedEvents.append(event)
        return event
    }

    func update(id: String, changes: EventChanges, among calendars: [EventCalendar]) throws -> Event {
        let current = try EventID.pick(matches(id: id, among: calendars), editableCalendarIds: editableIds(calendars), forWrite: true)
        let start = changes.start ?? Dates.parse(current.start)!
        let externalId = String(current.id[..<current.id.lastIndex(of: ":")!])
        let updated = Event(
            id: EventID.format(externalId: externalId, localId: "", recurring: current.recurring, start: start),
            start: Dates.format(start), end: changes.end.map(Dates.format) ?? current.end, allDay: current.allDay,
            title: changes.title ?? current.title, calendarId: current.calendarId, calendarName: current.calendarName,
            location: changes.location ?? current.location, notes: changes.notes ?? current.notes, url: current.url,
            status: current.status, organizer: current.organizer, attendees: current.attendees, recurring: current.recurring,
            externalId: nil, seriesId: nil, conferenceUrl: nil, created: nil, updated: nil
        )
        storedEvents.removeAll { $0.id == current.id && $0.calendarId == current.calendarId }
        storedEvents.append(updated)
        return updated
    }

    func delete(id: String, among calendars: [EventCalendar]) throws {
        let current = try EventID.pick(matches(id: id, among: calendars), editableCalendarIds: editableIds(calendars), forWrite: true)
        storedEvents.removeAll { $0.id == current.id && $0.calendarId == current.calendarId }
    }

    private func editableIds(_ calendars: [EventCalendar]) -> Set<String> {
        Set(calendars.filter(\.editable).map(\.id))
    }

    private func writableCalendar(_ id: String?, among calendars: [EventCalendar]) throws -> EventCalendar {
        guard let id, let calendar = calendars.first(where: { $0.id == id }) else { throw ToolError.notFound("calendar") }
        guard calendar.editable else { throw ToolError.readOnly(calendar.id) }
        return calendar
    }
}
