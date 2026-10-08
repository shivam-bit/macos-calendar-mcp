import Testing
@testable import MacOSCalendarMCP

@Suite("Settings")
struct SettingsTests {
    @Test("flags and env combine into one block list")
    func flagsAndEnvCombine() throws {
        let settings = try Settings.parse(
            arguments: ["macos-calendar-mcp", "--block-account", "a1", "--block-calendar", "c1", "--mirror", "/tmp/m.sqlite"],
            environment: ["MACOS_CALENDAR_BLOCKED_ACCOUNTS": "a2, a3", "MACOS_CALENDAR_BLOCKED_CALENDARS": "c2"]
        )
        #expect(settings.blockedAccountIds == ["a1", "a2", "a3"])
        #expect(settings.blockedCalendarIds == ["c1", "c2"])
        #expect(settings.mirrorPath == "/tmp/m.sqlite")
    }

    @Test("no input means nothing blocked and the default mirror path")
    func defaults() throws {
        let settings = try Settings.parse(arguments: ["macos-calendar-mcp"], environment: [:])
        #expect(settings.blockedAccountIds.isEmpty)
        #expect(settings.blockedCalendarIds.isEmpty)
        #expect(settings.mirrorPath.hasSuffix("Library/Application Support/macos-calendar-mcp/events.sqlite"))
    }

    @Test("a flag without a value is rejected")
    func missingValue() {
        #expect(throws: SettingsError.missingValue("--block-account")) {
            try Settings.parse(arguments: ["x", "--block-account"], environment: [:])
        }
    }

    @Test("an unknown flag is rejected")
    func unknownFlag() {
        #expect(throws: SettingsError.unknownFlag("--nope")) {
            try Settings.parse(arguments: ["x", "--nope", "1"], environment: [:])
        }
    }
}
