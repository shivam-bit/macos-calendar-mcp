import Foundation
import Testing
@testable import MacOSCalendarMCP

@Suite("List mode")
struct ListModeTests {
    let work = makeCalendar(id: "work")
    let second = makeCalendar(id: "second", accountId: "google")

    @Test("is requested only when the variable is exactly 1")
    func isRequested() {
        #expect(ListMode.isRequested(environment: ["MACOS_CALENDAR_LIST_CALENDARS": "1"]))
        #expect(!ListMode.isRequested(environment: ["MACOS_CALENDAR_LIST_CALENDARS": "true"]))
        #expect(!ListMode.isRequested(environment: ["MACOS_CALENDAR_LIST_CALENDARS": "0"]))
        #expect(!ListMode.isRequested(environment: [:]))
    }

    @Test("granted access prints every calendar as a JSON array and exits 0")
    func granted() async throws {
        let source = FakeCalendarSource(calendars: [work, second], events: [])
        let output = Output()
        let code = await ListMode.run(source: source, write: output.out, writeError: output.err)
        #expect(code == 0)
        #expect(output.errors.isEmpty)
        let decoded = try JSONDecoder().decode([EventCalendar].self, from: Data(output.text.utf8))
        #expect(decoded.map(\.id) == ["work", "second"])
    }

    @Test("denied access exits 1, writes only to stderr and does not ask for access")
    func denied() async {
        let source = FakeCalendarSource(calendars: [work], events: [], permission: .notDetermined)
        let output = Output()
        let code = await ListMode.run(source: source, write: output.out, writeError: output.err)
        #expect(code == 1)
        #expect(output.text.isEmpty)
        #expect(output.errors.joined().contains("Calendar access is not granted"))
        #expect(await source.permission() == .notDetermined)
    }
}
