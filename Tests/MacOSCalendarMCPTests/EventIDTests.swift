import Foundation
import Testing
@testable import MacOSCalendarMCP

@Suite("EventID")
struct EventIDTests {
    let start = Date(timeIntervalSince1970: 1_790_000_000.5)

    @Test("external id gets the occurrence start in ms, recurring or not")
    func externalFormat() {
        #expect(EventID.format(externalId: "abc@google.com", localId: "L1", recurring: false, start: start) == "abc@google.com:1790000000500")
        #expect(EventID.format(externalId: "abc@google.com", localId: "L1", recurring: true, start: start) == "abc@google.com:1790000000500")
    }

    @Test("without an external id, a single event uses the bare local id")
    func localSingle() {
        #expect(EventID.format(externalId: nil, localId: "L1", recurring: false, start: start) == "L1")
        #expect(EventID.format(externalId: "", localId: "L1", recurring: false, start: start) == "L1")
    }

    @Test("without an external id, a recurring event adds the start")
    func localRecurring() {
        #expect(EventID.format(externalId: nil, localId: "L1", recurring: true, start: start) == "L1:1790000000500")
    }

    @Test("occurrence start is read back from the suffix")
    func occurrenceStart() {
        #expect(EventID.occurrenceStart(of: "abc@google.com:1790000000500") == Date(timeIntervalSince1970: 1_790_000_000.5))
        #expect(EventID.occurrenceStart(of: "L1") == nil)
        #expect(EventID.occurrenceStart(of: "") == nil)
        #expect(EventID.occurrenceStart(of: "weird:12ab") == nil)
    }

    @Test("reads take the first match")
    func pickForRead() throws {
        let first = makeEvent(start: start, calendarId: "holidays")
        let second = makeEvent(start: start, calendarId: "work")
        #expect(try EventID.pick([first, second], editableCalendarIds: ["work"], forWrite: false) == first)
    }

    @Test("writes prefer a copy in an editable calendar")
    func pickForWrite() throws {
        let readOnlyCopy = makeEvent(start: start, calendarId: "holidays")
        let editableCopy = makeEvent(start: start, calendarId: "work")
        #expect(try EventID.pick([readOnlyCopy, editableCopy], editableCalendarIds: ["work"], forWrite: true) == editableCopy)
    }

    @Test("writes with only read-only copies are refused")
    func pickReadOnly() {
        let readOnlyCopy = makeEvent(start: start, calendarId: "holidays")
        #expect(throws: ToolError.readOnly("holidays")) {
            try EventID.pick([readOnlyCopy], editableCalendarIds: ["work"], forWrite: true)
        }
    }

    @Test("no matches is not found")
    func pickNone() {
        #expect(throws: ToolError.notFound("event")) {
            try EventID.pick([], editableCalendarIds: [], forWrite: false)
        }
    }
}
