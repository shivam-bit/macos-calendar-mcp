import Foundation
@testable import MacOSCalendarMCP

func makeCalendar(
    id: String,
    accountId: String = "icloud",
    name: String? = nil,
    editable: Bool = true
) -> EventCalendar {
    EventCalendar(
        id: id,
        name: name ?? id,
        account: Account(id: accountId, name: accountId, type: "calDAV"),
        color: nil,
        editable: editable,
        subscribed: false,
        isDefault: false,
        type: "calDAV"
    )
}

func makeEvent(
    externalId: String = "ext-1",
    start: Date,
    minutes: Int = 30,
    calendarId: String = "work",
    title: String = "Standup",
    notes: String? = nil,
    recurring: Bool = false
) -> Event {
    Event(
        id: EventID.format(externalId: externalId, localId: "local-\(externalId)", recurring: recurring, start: start),
        start: Dates.format(start),
        end: Dates.format(start.addingTimeInterval(TimeInterval(minutes * 60))),
        allDay: false,
        title: title,
        calendarId: calendarId,
        calendarName: calendarId,
        location: nil,
        notes: notes,
        url: nil,
        status: "confirmed",
        organizer: nil,
        attendees: [],
        recurring: recurring,
        externalId: nil,
        seriesId: nil,
        conferenceUrl: nil,
        created: nil,
        updated: nil
    )
}

func unavailableMirror() -> MirrorProvider {
    MirrorProvider(path: "/dev/null/mirror/events.sqlite")
}
