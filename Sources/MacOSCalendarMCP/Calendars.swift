import AppKit
@preconcurrency import EventKit
import Foundation

public actor EventKitCalendars: CalendarSource {
    private var store = EKEventStore()

    private static let noDefaultCalendar = ToolError.invalidInput("No default calendar is available; pass calendarId from list_calendars")

    public init() {}

    public func permission() -> CalendarPermission {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    public func requestAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        // A store created before the grant keeps seeing no calendars
        store = EKEventStore()
        return granted
    }

    public func calendars() -> [EventCalendar] {
        let defaultId = store.defaultCalendarForNewEvents?.calendarIdentifier
        return store.calendars(for: .event).map { calendar(from: $0, defaultId: defaultId) }
    }

    public func events(among calendars: [EventCalendar], from: Date, to: Date) -> [Event] {
        ekEvents(among: calendars, from: from, to: to).map(event(from:))
    }

    public func matches(id: String, among calendars: [EventCalendar]) -> [Event] {
        ekMatches(id: id, among: calendars).map(event(from:))
    }

    public func create(_ draft: EventDraft, among calendars: [EventCalendar]) throws -> Event {
        let targetId: String
        if let requested = draft.calendarId {
            targetId = requested
        } else {
            guard let defaultId = store.defaultCalendarForNewEvents?.calendarIdentifier,
                  calendars.contains(where: { $0.id == defaultId }) else { throw Self.noDefaultCalendar }
            targetId = defaultId
        }
        guard let visible = calendars.first(where: { $0.id == targetId }),
              let ekCalendar = store.calendar(withIdentifier: targetId) else {
            throw ToolError.notFound("calendar")
        }
        guard visible.editable else { throw ToolError.readOnly(targetId) }
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.calendar = ekCalendar
        ekEvent.title = draft.title
        ekEvent.startDate = draft.start
        ekEvent.endDate = draft.end
        ekEvent.isAllDay = draft.allDay
        ekEvent.location = draft.location
        ekEvent.notes = draft.notes
        ekEvent.url = draft.url
        try save(ekEvent)
        return event(from: ekEvent)
    }

    public func update(id: String, changes: EventChanges, among calendars: [EventCalendar]) throws -> Event {
        let ekEvent = try ekWritable(id: id, among: calendars)
        if let title = changes.title { ekEvent.title = title }
        if let start = changes.start { ekEvent.startDate = start }
        if let end = changes.end { ekEvent.endDate = end }
        if let location = changes.location { ekEvent.location = location }
        if let notes = changes.notes { ekEvent.notes = notes }
        guard ekEvent.endDate > ekEvent.startDate else { throw ToolError.invalidInput("end must be after start") }
        try save(ekEvent)
        return event(from: ekEvent)
    }

    public func delete(id: String, among calendars: [EventCalendar]) throws {
        let ekEvent = try ekWritable(id: id, among: calendars)
        do {
            try store.remove(ekEvent, span: .thisEvent, commit: true)
        } catch {
            throw ToolError.unavailable("Calendar refused the delete: \(error.localizedDescription)")
        }
    }

    // Lookups are always scoped to the given calendars

    private func ekCalendars(_ calendars: [EventCalendar]) -> [EKCalendar] {
        calendars.compactMap { store.calendar(withIdentifier: $0.id) }
    }

    private func ekEvents(among calendars: [EventCalendar], from: Date, to: Date) -> [EKEvent] {
        let scoped = ekCalendars(calendars)
        // EventKit reads an empty calendar list as "every calendar"
        guard !scoped.isEmpty else { return [] }
        return store.events(matching: store.predicateForEvents(withStart: from, end: to, calendars: scoped))
            .sorted { ($0.startDate, $0.calendarItemIdentifier) < ($1.startDate, $1.calendarItemIdentifier) }
    }

    private func ekMatches(id: String, among calendars: [EventCalendar]) -> [EKEvent] {
        guard let start = EventID.occurrenceStart(of: id) else {
            let visibleIds = Set(calendars.map(\.id))
            guard let item = store.calendarItem(withIdentifier: id) as? EKEvent,
                  !item.hasRecurrenceRules,
                  visibleIds.contains(item.calendar.calendarIdentifier) else { return [] }
            return [item]
        }
        return ekEvents(among: calendars, from: start, to: start.addingTimeInterval(60))
            .filter { eventID(of: $0) == id }
    }

    private func ekWritable(id: String, among calendars: [EventCalendar]) throws -> EKEvent {
        let candidates = ekMatches(id: id, among: calendars)
        let editableIds = Set(calendars.filter(\.editable).map(\.id))
        let picked = try EventID.pick(candidates.map(event(from:)), editableCalendarIds: editableIds, forWrite: true)
        return candidates.first { $0.calendar.calendarIdentifier == picked.calendarId }!
    }

    private func save(_ ekEvent: EKEvent) throws {
        do {
            try store.save(ekEvent, span: .thisEvent, commit: true)
        } catch {
            throw ToolError.unavailable("Calendar refused the change: \(error.localizedDescription)")
        }
    }

    private func eventID(of ekEvent: EKEvent) -> String {
        EventID.format(
            externalId: ekEvent.calendarItemExternalIdentifier,
            localId: ekEvent.calendarItemIdentifier,
            recurring: ekEvent.hasRecurrenceRules,
            start: ekEvent.startDate
        )
    }

    private func event(from ekEvent: EKEvent) -> Event {
        Event(
            id: eventID(of: ekEvent),
            start: Dates.format(ekEvent.startDate),
            end: Dates.format(ekEvent.endDate),
            allDay: ekEvent.isAllDay,
            title: ekEvent.title ?? "",
            calendarId: ekEvent.calendar.calendarIdentifier,
            calendarName: ekEvent.calendar.title,
            location: ekEvent.location,
            notes: ekEvent.notes,
            url: ekEvent.url?.absoluteString,
            status: status(ekEvent.status),
            organizer: ekEvent.organizer.map(person(from:)),
            attendees: Person.stableOrder((ekEvent.attendees ?? []).map(person(from:))),
            recurring: ekEvent.hasRecurrenceRules,
            externalId: ekEvent.calendarItemExternalIdentifier,
            seriesId: ekEvent.hasRecurrenceRules ? seriesId(of: ekEvent) : nil,
            conferenceUrl: ConferenceLink.find(url: ekEvent.url?.absoluteString, notes: ekEvent.notes, location: ekEvent.location),
            created: ekEvent.creationDate.map(Dates.format),
            updated: ekEvent.lastModifiedDate.map(Dates.format)
        )
    }

    private func seriesId(of ekEvent: EKEvent) -> String {
        if let externalId = ekEvent.calendarItemExternalIdentifier, !externalId.isEmpty { return externalId }
        return ekEvent.calendarItemIdentifier
    }

    private func calendar(from ekCalendar: EKCalendar, defaultId: String?) -> EventCalendar {
        EventCalendar(
            id: ekCalendar.calendarIdentifier,
            name: ekCalendar.title,
            account: Account(
                id: ekCalendar.source.sourceIdentifier,
                name: ekCalendar.source.title,
                type: sourceType(ekCalendar.source.sourceType)
            ),
            color: hex(ekCalendar.cgColor),
            editable: ekCalendar.allowsContentModifications,
            subscribed: ekCalendar.isSubscribed,
            isDefault: ekCalendar.calendarIdentifier == defaultId,
            type: calendarType(ekCalendar.type)
        )
    }

    private func person(from participant: EKParticipant) -> Person {
        let email = participant.url.scheme == "mailto"
            ? participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            : nil
        return Person(
            name: participant.name,
            email: email?.isEmpty == true ? nil : email,
            isSelf: participant.isCurrentUser,
            status: participantStatus(participant.participantStatus)
        )
    }

    private func status(_ status: EKEventStatus) -> String {
        switch status {
        case .confirmed: "confirmed"
        case .tentative: "tentative"
        case .canceled: "cancelled"
        default: "none"
        }
    }

    private func participantStatus(_ status: EKParticipantStatus) -> String {
        switch status {
        case .accepted: "accepted"
        case .declined: "declined"
        case .tentative: "tentative"
        case .pending: "pending"
        default: "unknown"
        }
    }

    private func sourceType(_ type: EKSourceType) -> String {
        switch type {
        case .local: "local"
        case .exchange: "exchange"
        case .calDAV: "calDAV"
        case .mobileMe: "mobileMe"
        case .subscribed: "subscribed"
        case .birthdays: "birthdays"
        @unknown default: "other"
        }
    }

    private func calendarType(_ type: EKCalendarType) -> String {
        switch type {
        case .local: "local"
        case .calDAV: "calDAV"
        case .exchange: "exchange"
        case .subscription: "subscription"
        case .birthday: "birthday"
        @unknown default: "other"
        }
    }

    private func hex(_ color: CGColor?) -> String? {
        guard let color, let rgb = NSColor(cgColor: color)?.usingColorSpace(.sRGB) else { return nil }
        let channel = { (value: CGFloat) in Int((value * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(rgb.redComponent), channel(rgb.greenComponent), channel(rgb.blueComponent))
    }
}
