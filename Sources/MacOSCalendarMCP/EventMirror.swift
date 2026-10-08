import Foundation
import SQLite3

public struct EventChange: Codable, Equatable, Sendable {
    public let id: String
    public let calendarId: String
    public let version: Int64
    public let deleted: Bool
    public let event: Event?
}

public enum ChangesPage: Equatable, Sendable {
    case reset
    case page(changes: [EventChange], next: Int64, hasMore: Bool)
}

public actor MirrorProvider {
    private let path: String
    private var opened: EventMirror?

    public init(path: String) { self.path = path }

    public func mirror() throws -> EventMirror {
        if let opened { return opened }
        let mirror = try EventMirror(path: path)
        opened = mirror
        return mirror
    }
}

public actor EventMirror {
    private static let tombstoneLifetime: TimeInterval = 30 * 86400
    private nonisolated(unsafe) let db: OpaquePointer

    public init(path: String) throws {
        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true
            )
        } catch {
            throw ToolError.unavailable("Can't open the event mirror at \(path)")
        }
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK, let handle else {
            throw ToolError.unavailable("Can't open the event mirror at \(path)")
        }
        db = handle
        sqlite3_busy_timeout(db, 5000)
        try Self.exec(db, """
            PRAGMA journal_mode = WAL;
            CREATE TABLE IF NOT EXISTS events (
              id TEXT NOT NULL, calendar_id TEXT NOT NULL, account_id TEXT NOT NULL,
              start_ms INTEGER NOT NULL, body TEXT, deleted INTEGER NOT NULL DEFAULT 0,
              version INTEGER NOT NULL, changed_ms INTEGER NOT NULL,
              PRIMARY KEY (id, calendar_id)
            );
            CREATE INDEX IF NOT EXISTS events_version ON events(version);
            CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL);
            INSERT OR IGNORE INTO meta VALUES ('version', 0), ('pruned_through', 0), ('last_read_ms', 0);
            """)
    }

    deinit { sqlite3_close(db) }

    public static func window(now: Date) -> (start: Date, end: Date) {
        (now.addingTimeInterval(-7 * 86400), now.addingTimeInterval(14 * 86400))
    }

    public func refresh(calendars: [EventCalendar], events: [Event], now: Date, readAt: Date) throws {
        let accountByCalendar = Dictionary(calendars.map { ($0.id, $0.account.id) }, uniquingKeysWith: { first, _ in first })
        let windowStartMs = Self.ms(Self.window(now: now).start)
        let nowMs = Self.ms(now)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        try Self.exec(db, "BEGIN IMMEDIATE")
        do {
            let readAtMs = Self.ms(readAt)
            guard readAtMs >= (try metaValue("last_read_ms")) else {
                try Self.exec(db, "ROLLBACK")
                return
            }
            var version = try metaValue("version")
            let stored = try storedRows()
            let seenKeys = Set(events.map { RowKey(id: $0.id, calendarId: $0.calendarId) })

            // Tombstones come first so a move between calendars deletes the old row at a lower version than it upserts the new one
            for (key, row) in stored where !row.deleted && !seenKeys.contains(key) {
                if row.startMs < windowStartMs {
                    try run("DELETE FROM events WHERE id = ? AND calendar_id = ?", [.text(key.id), .text(key.calendarId)])
                } else {
                    version += 1
                    try run("UPDATE events SET deleted = 1, body = NULL, version = ?, changed_ms = ? WHERE id = ? AND calendar_id = ?",
                            [.int(version), .int(nowMs), .text(key.id), .text(key.calendarId)])
                }
            }

            for event in events {
                let key = RowKey(id: event.id, calendarId: event.calendarId)
                let body = String(decoding: try encoder.encode(event), as: UTF8.self)
                if let row = stored[key], !row.deleted, row.body == body { continue }
                version += 1
                try run("""
                    INSERT INTO events (id, calendar_id, account_id, start_ms, body, deleted, version, changed_ms)
                    VALUES (?, ?, ?, ?, ?, 0, ?, ?)
                    ON CONFLICT (id, calendar_id) DO UPDATE SET account_id = excluded.account_id,
                      start_ms = excluded.start_ms, body = excluded.body, deleted = 0,
                      version = excluded.version, changed_ms = excluded.changed_ms
                    """, [.text(event.id), .text(event.calendarId), .text(accountByCalendar[event.calendarId] ?? ""),
                          .int(Self.ms(Dates.parse(event.start) ?? now)), .text(body), .int(version), .int(nowMs)])
            }

            try pruneTombstones(olderThanMs: nowMs - Int64(Self.tombstoneLifetime * 1000))
            try run("UPDATE meta SET value = ? WHERE key = 'version'", [.int(version)])
            try run("UPDATE meta SET value = ? WHERE key = 'last_read_ms'", [.int(readAtMs)])
            try Self.exec(db, "COMMIT")
        } catch {
            try? Self.exec(db, "ROLLBACK")
            throw error
        }
    }

    public func changes(after: Int64, limit: Int, access: CalendarAccess) throws -> ChangesPage {
        if after > 0, after < (try metaValue("pruned_through")) { return .reset }
        let currentVersion = try metaValue("version")
        if after > currentVersion { return .reset }
        let decoder = JSONDecoder()
        var changes: [EventChange] = []
        var hasMore = false
        let sql = "SELECT id, calendar_id, account_id, body, deleted, version FROM events WHERE version > ? ORDER BY version"
        try query(sql, [.int(after)]) { row in
            let deleted = row.int(4) == 1
            guard access.isVisible(calendarId: row.text(1), accountId: row.text(2)), !(after == 0 && deleted) else { return true }
            guard changes.count < limit else { hasMore = true; return false }
            let event = row.optionalText(3).flatMap { try? decoder.decode(Event.self, from: Data($0.utf8)) }
            changes.append(EventChange(id: row.text(0), calendarId: row.text(1), version: row.int(5), deleted: deleted, event: event))
            return true
        }
        let next = hasMore ? (changes.last?.version ?? after) : currentVersion
        return .page(changes: changes, next: next, hasMore: hasMore)
    }

    private struct RowKey: Hashable { let id: String; let calendarId: String }
    private struct StoredRow { let startMs: Int64; let body: String?; let deleted: Bool }

    private func storedRows() throws -> [RowKey: StoredRow] {
        var rows: [RowKey: StoredRow] = [:]
        try query("SELECT id, calendar_id, start_ms, body, deleted FROM events", []) { row in
            rows[RowKey(id: row.text(0), calendarId: row.text(1))] =
                StoredRow(startMs: row.int(2), body: row.optionalText(3), deleted: row.int(4) == 1)
            return true
        }
        return rows
    }

    private func pruneTombstones(olderThanMs cutoffMs: Int64) throws {
        var prunedThrough = try metaValue("pruned_through")
        try query("SELECT MAX(version) FROM events WHERE deleted = 1 AND changed_ms < ?", [.int(cutoffMs)]) { row in
            if let newest = row.optionalInt(0) { prunedThrough = max(prunedThrough, newest) }
            return false
        }
        try run("DELETE FROM events WHERE deleted = 1 AND changed_ms < ?", [.int(cutoffMs)])
        try run("UPDATE meta SET value = ? WHERE key = 'pruned_through'", [.int(prunedThrough)])
    }

    private func metaValue(_ key: String) throws -> Int64 {
        var value: Int64 = 0
        try query("SELECT value FROM meta WHERE key = ?", [.text(key)]) { row in value = row.int(0); return false }
        return value
    }

    private static func ms(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

    private enum Binding { case text(String), int(Int64) }

    private struct Row {
        let statement: OpaquePointer
        func text(_ column: Int32) -> String { String(cString: sqlite3_column_text(statement, column)) }
        func optionalText(_ column: Int32) -> String? {
            sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : text(column)
        }
        func int(_ column: Int32) -> Int64 { sqlite3_column_int64(statement, column) }
        func optionalInt(_ column: Int32) -> Int64? {
            sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : int(column)
        }
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw ToolError.unavailable("Event mirror error: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func run(_ sql: String, _ bindings: [Binding]) throws {
        try query(sql, bindings) { _ in false }
    }

    // onRow returns false to stop early
    private func query(_ sql: String, _ bindings: [Binding], onRow: (Row) throws -> Bool) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ToolError.unavailable("Event mirror error: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch binding {
            case .text(let value): sqlite3_bind_text(statement, position, value, -1, transient)
            case .int(let value): sqlite3_bind_int64(statement, position, value)
            }
        }
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return }
            guard status == SQLITE_ROW else {
                throw ToolError.unavailable("Event mirror error: \(String(cString: sqlite3_errmsg(db)))")
            }
            guard try onRow(Row(statement: statement)) else { return }
        }
    }
}
