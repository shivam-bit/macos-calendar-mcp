import Foundation

// Same format as ContextKit's EventKitEventMapper.eventId, so backend rows keep matching
enum EventID {
    static func format(externalId: String?, localId: String, recurring: Bool, start: Date) -> String {
        let startMs = Int64(start.timeIntervalSince1970 * 1000)
        if let externalId, !externalId.isEmpty { return "\(externalId):\(startMs)" }
        return recurring ? "\(localId):\(startMs)" : localId
    }

    static func occurrenceStart(of id: String) -> Date? {
        guard let colon = id.lastIndex(of: ":") else { return nil }
        let suffix = id[id.index(after: colon)...]
        guard suffix.allSatisfy(\.isNumber), let startMs = Int64(suffix) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
    }

    static func pick(_ matches: [Event], editableCalendarIds: Set<String>, forWrite: Bool) throws -> Event {
        guard let first = matches.first else { throw ToolError.notFound("event") }
        guard forWrite else { return first }
        guard let editable = matches.first(where: { editableCalendarIds.contains($0.calendarId) }) else {
            throw ToolError.readOnly(first.calendarId)
        }
        return editable
    }
}
