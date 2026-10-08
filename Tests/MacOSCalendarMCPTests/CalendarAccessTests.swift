import Testing
@testable import MacOSCalendarMCP

@Suite("CalendarAccess")
struct CalendarAccessTests {
    let work = makeCalendar(id: "work", accountId: "icloud")
    let home = makeCalendar(id: "home", accountId: "icloud")
    let gmail = makeCalendar(id: "gmail", accountId: "google")

    func access(accounts: Set<String> = [], calendars: Set<String> = []) -> CalendarAccess {
        CalendarAccess(settings: Settings(blockedAccountIds: accounts, blockedCalendarIds: calendars, mirrorPath: ""))
    }

    @Test("blocking an account hides all of its calendars")
    func blockedAccount() {
        #expect(access(accounts: ["icloud"]).visible([work, home, gmail]) == [gmail])
    }

    @Test("blocking a calendar hides only that calendar")
    func blockedCalendar() {
        #expect(access(calendars: ["home"]).visible([work, home, gmail]) == [work, gmail])
    }

    @Test("unknown blocked ids hide nothing")
    func unknownBlockedIdsHideNothing() {
        #expect(access(accounts: ["nope"], calendars: ["nada"]).visible([work, home, gmail]) == [work, home, gmail])
    }

    @Test("row-level check uses calendar and account ids")
    func rowCheck() {
        let rule = access(accounts: ["google"], calendars: ["home"])
        #expect(rule.isVisible(calendarId: "work", accountId: "icloud"))
        #expect(!rule.isVisible(calendarId: "home", accountId: "icloud"))
        #expect(!rule.isVisible(calendarId: "anything", accountId: "google"))
    }
}
