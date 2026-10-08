public struct CalendarAccess: Sendable {
    private let blockedAccountIds: Set<String>
    private let blockedCalendarIds: Set<String>

    public init(settings: Settings) {
        blockedAccountIds = settings.blockedAccountIds
        blockedCalendarIds = settings.blockedCalendarIds
    }

    public func isVisible(calendarId: String, accountId: String) -> Bool {
        !blockedCalendarIds.contains(calendarId) && !blockedAccountIds.contains(accountId)
    }

    public func isVisible(_ calendar: EventCalendar) -> Bool {
        isVisible(calendarId: calendar.id, accountId: calendar.account.id)
    }

    public func visible(_ calendars: [EventCalendar]) -> [EventCalendar] {
        calendars.filter(isVisible)
    }
}
