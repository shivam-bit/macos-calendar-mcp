import Foundation
import Testing
@testable import MacOSCalendarMCP

@Suite("Dates")
struct DatesTests {
    @Test("an offset date round-trips through format and parse")
    func roundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(Dates.parse(Dates.format(date)) == date)
    }

    @Test("a date with Z or an offset parses to the same instant")
    func offsets() {
        #expect(Dates.parse("2026-10-08T07:30:00Z") == Dates.parse("2026-10-08T13:00:00+05:30"))
    }

    @Test("a date without a timezone uses the local timezone")
    func naiveIsLocal() throws {
        let parsed = try #require(Dates.parse("2026-10-08T13:00:00"))
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(parts.year == 2026 && parts.month == 10 && parts.day == 8 && parts.hour == 13 && parts.minute == 0)
    }

    @Test("a date-only value is local midnight")
    func dateOnly() throws {
        let parsed = try #require(Dates.parse("2026-10-08"))
        #expect(parsed == Calendar.current.startOfDay(for: parsed))
    }

    @Test("garbage does not parse")
    func parseRejectsGarbage() {
        #expect(Dates.parse("next tuesday") == nil)
        #expect(Dates.parse("") == nil)
        #expect(Dates.parse("2026-13-45T99:00:00") == nil)
    }
}
