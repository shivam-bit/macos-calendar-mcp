import Foundation

public enum ListMode {
    static let variable = "MACOS_CALENDAR_LIST_CALENDARS"
    static let notGranted = "Calendar access is not granted. Allow it in System Settings → Privacy & Security → Calendars."

    public static func isRequested(environment: [String: String]) -> Bool {
        environment[variable] == "1"
    }

    public static func run(
        source: any CalendarSource,
        write: @Sendable (String) -> Void = { FileHandle.standardOutput.write(Data($0.utf8)) },
        writeError: @Sendable (String) -> Void = { FileHandle.standardError.write(Data($0.utf8)) }
    ) async -> Int32 {
        guard await source.permission() == .granted else {
            writeError(notGranted + "\n")
            return 1
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(await source.calendars()) else {
            writeError("Could not encode the calendars.\n")
            return 1
        }
        write(String(decoding: data, as: UTF8.self) + "\n")
        return 0
    }
}
