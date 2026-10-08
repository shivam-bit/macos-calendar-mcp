import Foundation

public struct Account: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let type: String

    public init(id: String, name: String, type: String) {
        self.id = id
        self.name = name
        self.type = type
    }
}

public struct EventCalendar: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let account: Account
    public let color: String?
    public let editable: Bool
    public let subscribed: Bool
    public let isDefault: Bool
    public let type: String

    public init(
        id: String, name: String, account: Account, color: String?,
        editable: Bool, subscribed: Bool, isDefault: Bool, type: String
    ) {
        self.id = id
        self.name = name
        self.account = account
        self.color = color
        self.editable = editable
        self.subscribed = subscribed
        self.isDefault = isDefault
        self.type = type
    }
}

public struct Person: Codable, Equatable, Sendable {
    public let name: String?
    public let email: String?
    public let isSelf: Bool
    public let status: String?

    public init(name: String?, email: String?, isSelf: Bool, status: String?) {
        self.name = name
        self.email = email
        self.isSelf = isSelf
        self.status = status
    }

    // EventKit returns attendees in a different order per store instance
    static func stableOrder(_ people: [Person]) -> [Person] {
        people.sorted { lhs, rhs in
            let keys: [(String?, String?)] = [
                (lhs.email, rhs.email), (lhs.name, rhs.name),
            ]
            for (a, b) in keys where a != b {
                guard let a else { return false }
                guard let b else { return true }
                return a < b
            }
            if lhs.isSelf != rhs.isSelf { return !lhs.isSelf }
            switch (lhs.status, rhs.status) {
            case let (a?, b?): return a < b
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return false
            }
        }
    }
}

public struct Event: Codable, Equatable, Sendable {
    public let id: String
    public let start: String
    public let end: String
    public let allDay: Bool
    public let title: String
    public let calendarId: String
    public let calendarName: String
    public let location: String?
    public let notes: String?
    public let url: String?
    public let status: String
    public let organizer: Person?
    public let attendees: [Person]
    public let recurring: Bool

    public init(
        id: String, start: String, end: String, allDay: Bool, title: String,
        calendarId: String, calendarName: String, location: String?, notes: String?, url: String?,
        status: String, organizer: Person?, attendees: [Person], recurring: Bool
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.allDay = allDay
        self.title = title
        self.calendarId = calendarId
        self.calendarName = calendarName
        self.location = location
        self.notes = notes
        self.url = url
        self.status = status
        self.organizer = organizer
        self.attendees = attendees
        self.recurring = recurring
    }
}
