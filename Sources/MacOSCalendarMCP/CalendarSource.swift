import Foundation

public enum CalendarPermission: Sendable { case granted, notDetermined, denied }

public struct EventDraft: Sendable {
    public var title: String
    public var start: Date
    public var end: Date
    public var allDay: Bool
    public var calendarId: String?
    public var location: String?
    public var notes: String?
    public var url: URL?

    public init(
        title: String, start: Date, end: Date, allDay: Bool, calendarId: String?,
        location: String?, notes: String?, url: URL?
    ) {
        self.title = title
        self.start = start
        self.end = end
        self.allDay = allDay
        self.calendarId = calendarId
        self.location = location
        self.notes = notes
        self.url = url
    }
}

public struct EventChanges: Sendable {
    public var title: String?
    public var start: Date?
    public var end: Date?
    public var location: String?
    public var notes: String?

    public init(title: String? = nil, start: Date? = nil, end: Date? = nil, location: String? = nil, notes: String? = nil) {
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.notes = notes
    }

    public var isEmpty: Bool { title == nil && start == nil && end == nil && location == nil && notes == nil }
}

public protocol CalendarSource: Sendable {
    func permission() async -> CalendarPermission
    func requestAccess() async -> Bool
    func calendars() async -> [EventCalendar]
    func events(among calendars: [EventCalendar], from: Date, to: Date) async -> [Event]
    func matches(id: String, among calendars: [EventCalendar]) async -> [Event]
    func create(_ draft: EventDraft, among calendars: [EventCalendar]) async throws -> Event
    func update(id: String, changes: EventChanges, among calendars: [EventCalendar]) async throws -> Event
    func delete(id: String, among calendars: [EventCalendar]) async throws
}
