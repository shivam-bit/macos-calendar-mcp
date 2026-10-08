import Testing
@testable import MacOSCalendarMCP

@Suite("Conference link")
struct ConferenceLinkTests {
    @Test("a conference url field wins over links in the notes")
    func urlWins() {
        let found = ConferenceLink.find(
            url: "https://acme.zoom.us/j/123", notes: "https://meet.google.com/abc-defg-hij", location: nil
        )
        #expect(found == "https://acme.zoom.us/j/123")
    }

    @Test("finds a link inside notes text and keeps its case")
    func linkInNotes() {
        let found = ConferenceLink.find(url: nil, notes: "Join here: https://meet.google.com/Abc-defg-hij thanks", location: nil)
        #expect(found == "https://meet.google.com/Abc-defg-hij")
    }

    @Test("matches each conference host", arguments: [
        "https://acme.zoom.us/j/1", "https://meet.google.com/abc", "https://teams.microsoft.com/l/1",
        "https://teams.live.com/meet/1", "https://acme.webex.com/m/1", "https://whereby.com/room",
        "https://www.gotomeeting.com/join/1", "https://facetime.apple.com/join#v=1",
    ])
    func eachHost(link: String) {
        #expect(ConferenceLink.find(url: link, notes: nil, location: nil) == link)
        #expect(ConferenceLink.find(url: nil, notes: "Join: \(link) soon", location: nil) == link)
    }

    @Test("matches an upper-case host")
    func upperCase() {
        #expect(ConferenceLink.find(url: "https://ACME.ZOOM.US/j/1", notes: nil, location: nil) == "https://ACME.ZOOM.US/j/1")
    }

    @Test("a non-conference url does not block a conference link in notes")
    func otherUrlThenNotes() {
        let found = ConferenceLink.find(url: "https://example.com/agenda", notes: "https://acme.zoom.us/j/2", location: nil)
        #expect(found == "https://acme.zoom.us/j/2")
    }

    @Test("ignores a url that is not a conference host")
    func ignoresOtherUrls() {
        let found = ConferenceLink.find(url: "https://example.com/agenda", notes: "see https://example.com/doc", location: nil)
        #expect(found == nil)
    }

    @Test("returns nil when every field is nil")
    func allNil() {
        #expect(ConferenceLink.find(url: nil, notes: nil, location: nil) == nil)
    }

    @Test("notes are checked before location")
    func notesBeforeLocation() {
        let found = ConferenceLink.find(
            url: nil, notes: "https://teams.microsoft.com/l/meetup-join/1", location: "https://acme.zoom.us/j/9"
        )
        #expect(found == "https://teams.microsoft.com/l/meetup-join/1")
    }

    @Test("finds a link in the location")
    func linkInLocation() {
        #expect(ConferenceLink.find(url: nil, notes: nil, location: "https://whereby.com/room") == "https://whereby.com/room")
    }
}
