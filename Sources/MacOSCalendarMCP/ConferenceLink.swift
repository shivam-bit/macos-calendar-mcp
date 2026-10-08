import Foundation

enum ConferenceLink {
    private static let hosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "gotomeeting.com", "facetime.apple.com",
    ]
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func find(url: String?, notes: String?, location: String?) -> String? {
        if let url, isConference(url) { return url }
        return [notes, location].compactMap { $0 }.lazy.compactMap(firstLink(in:)).first
    }

    private static func isConference(_ link: String) -> Bool {
        let lowered = link.lowercased()
        return hosts.contains { lowered.contains($0) }
    }

    private static func firstLink(in text: String) -> String? {
        guard let detector else { return nil }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
            .first(where: isConference)
    }
}
