public enum ToolError: Error, Equatable {
    case notFound(String)
    case readOnly(String)
    case invalidInput(String)
    case accessDenied
    case unavailable(String)

    var error: String {
        switch self {
        case .notFound(let thing): "\(thing.prefix(1).uppercased())\(thing.dropFirst()) not found."
        case .readOnly: "That calendar can't be changed."
        case .invalidInput(let reason): reason
        case .accessDenied: "Calendar access is not granted."
        case .unavailable(let reason): reason
        }
    }

    var hint: String {
        switch self {
        case .notFound: "Use list_calendars or list_events to get a current id."
        case .readOnly: "Pick a calendar where list_calendars shows editable: true."
        case .invalidInput: "Fix the input and try again."
        case .accessDenied:
            "Allow Calendars for the app running this server in System Settings → Privacy & Security → Calendars, then try again."
        case .unavailable: "Try again. If it keeps failing, restart the app running this server."
        }
    }
}
