import Foundation
import Testing
@testable import MacOSCalendarMCP

@Suite("CalendarSource contract (fake)")
struct FakeCalendarSourceTests {
    let start = Date(timeIntervalSince1970: 1_790_000_000)
    let work = makeCalendar(id: "work")
    let holidays = makeCalendar(id: "holidays", editable: false)

    @Test("an empty calendar list returns no events")
    func emptyAmongReturnsNothing() async {
        let source = FakeCalendarSource(calendars: [work], events: [makeEvent(start: start)])
        #expect(await source.events(among: [], from: .distantPast, to: .distantFuture).isEmpty)
    }

    @Test("matches ignore calendars outside the list")
    func matchesRespectAmong() async {
        let event = makeEvent(start: start, calendarId: "work")
        let source = FakeCalendarSource(calendars: [work, holidays], events: [event])
        #expect(await source.matches(id: event.id, among: [holidays]).isEmpty)
        #expect(await source.matches(id: event.id, among: [work]) == [event])
    }
}
