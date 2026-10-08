# macos-calendar-mcp

`macos-calendar-mcp` is an MCP server for macOS Calendar. It runs over stdio and uses EventKit, so it reads and writes the same calendars as Calendar.app. It lists calendars, lists and searches events, creates, updates and deletes events, and reports changes for clients that keep a copy of the events. You can block accounts and single calendars so that no tool can see them.

## Install

Works on Apple Silicon and Intel Macs, macOS 14+.

### npm

```sh
npx -y macos-calendar-mcp
bunx macos-calendar-mcp
```

Add it to Claude Code:

```sh
claude mcp add macos-calendar -- npx -y macos-calendar-mcp
```

Other MCP clients (Cursor, Codex and others) take a `command` and `args` in their MCP configuration:

```json
{
  "mcpServers": {
    "macos-calendar": {
      "command": "npx",
      "args": ["-y", "macos-calendar-mcp"]
    }
  }
}
```

This variant blocks one account and one calendar:

```json
{
  "mcpServers": {
    "macos-calendar": {
      "command": "npx",
      "args": ["-y", "macos-calendar-mcp", "--block-account", "ACCOUNT_ID", "--block-calendar", "CALENDAR_ID"]
    }
  }
}
```

The same block list can be set with environment variables. See [Settings](#settings).

### GitHub release binary

Each release has a universal binary (Apple Silicon and Intel) as `macos-calendar-mcp-<tag>-macos-universal.tar.gz`, with a `.sha256` file. Download it from the [releases page](https://github.com/shivam-bit/macos-calendar-mcp/releases), extract it, and use its absolute path as the `command` in the configuration above.

### Build from source

This needs Swift 6.1 or later.

```sh
swift build -c release
```

The binary is `.build/release/macos-calendar-mcp`. To build the universal binary, run `scripts/build-universal.sh`.

## Releasing

1. Tag the commit `vX.Y.Z` and push the tag. The release workflow builds the universal binary and attaches it to a GitHub release. It also publishes to npm if the repository has an `NPM_TOKEN` secret.
2. To publish by hand, run `scripts/prepare-npm.sh`, then `npm publish` in `npm/`.

## Privacy model

- A blocked calendar or account does not exist for this server. No tool lists, reads, searches, creates, updates or deletes anything in it. Asking for an event in a blocked calendar returns "not found", the same as for an event that does not exist.
- The block list belongs to each server process. Two clients can run the server with different block lists.
- The server keeps a local SQLite file, the shared mirror, with a copy of the events from every calendar that macOS shows, blocked or not. All server processes share it, because they may have different block lists. Only `get_changes` reads it, and it removes blocked rows on read.
- Nothing leaves the Mac. The server makes no network requests. Event content is never written to the logs, which go to stderr.
- Removing data that a client already copied before you blocked a calendar is the client's job. The server sends no removals for a newly blocked calendar.

## Settings

Pass settings as launch arguments or environment variables. Block lists from both sources are combined.

| Argument | Environment variable | Meaning |
|---|---|---|
| `--block-account <id>` | `MACOS_CALENDAR_BLOCKED_ACCOUNTS` | Block every calendar in an account. Repeat the flag for more accounts. The variable takes a comma-separated list. |
| `--block-calendar <id>` | `MACOS_CALENDAR_BLOCKED_CALENDARS` | Block one calendar. Repeat the flag for more calendars. The variable takes a comma-separated list. |
| `--mirror <path>` | none | Path of the mirror file. The default is `~/Library/Application Support/macos-calendar-mcp/events.sqlite`. |

The server exits with an error on an unknown flag or a flag without a value.

Calendar and account IDs come from `list_calendars`. Each calendar has an `id`, and its `account.id` is the account ID. Titles are not unique, so use IDs. Once you block something, `list_calendars` no longer shows it, so read the IDs before you block, or run a second copy of the server without a block list.

The mirror file opens at the first `get_changes` call. If it cannot be opened, the other tools still work and `get_changes` returns an error. The next call tries again.

## Tools

All dates are ISO-8601, for example `2026-10-08T13:00:00`. A date without a timezone uses the Mac's local timezone. All tools return JSON as text. Failures return `{error, hint}` with the MCP error flag set.

| Tool | What it does |
|---|---|
| `list_calendars` | Lists the visible calendars with `id`, `name`, `account`, `color`, `editable`, `subscribed`, `isDefault` and `type`. Takes no input. |
| `list_events` | Lists events that overlap the range from `start` to `end` (both required, at most 366 days apart). Optional `calendarIds` limits it to some calendars. Optional `limit`: default 200, at most 1000. Returns `{events, truncated}`. |
| `search_events` | Finds events that overlap the range from `start` to `end` whose title, location or notes contain `text`, ignoring case. Optional `limit`: default 50, at most 500. Returns `{events, truncated}`. |
| `get_event` | Returns one event by `id`. |
| `create_event` | Creates an event from `title`, `start` and `end`. Optional `calendarId` (must be editable; the default is the Mac's default calendar), `allDay`, `location`, `notes` and `url`. |
| `update_event` | Changes one occurrence of an event by `id`. Give at least one of `title`, `start`, `end`, `location` and `notes`. Returns the event with its current `id`. |
| `delete_event` | Deletes one occurrence of an event by `id`. Returns `{deleted: id}`. |
| `get_changes` | Returns events added, changed or deleted after an offset. See [Syncing with get_changes](#syncing-with-get_changes). |

An event has `id`, `start`, `end`, `allDay`, `title`, `calendarId`, `calendarName`, `location`, `notes`, `url`, `status`, `organizer`, `attendees` and `recurring`.

### Event IDs

An event ID is `<externalIdentifier>:<occurrenceStartMs>`. The first part is the event's external identifier from the calendar server, and the second is the occurrence's start in milliseconds since 1970. If an event has no external identifier, the ID is its local identifier, with `:<occurrenceStartMs>` added when the event recurs.

An ID names one occurrence. Updating or deleting a recurring event changes only the occurrence you name.

The ID changes when an event's start changes, because the start is part of it. `update_event` returns the new ID. After you move an event, stop using the old ID.

The same invite can appear in two calendars with the same ID. Reads return the first copy. Writes use a copy in an editable calendar, and fail if every copy is read-only.

## Syncing with get_changes

`get_changes` is for clients that keep their own copy of the events. The server keeps no state per client. The client stores an offset.

1. Call `get_changes` with `after = 0`. This returns every current event in the window. Deleted events are not included.
2. Store the returned `next` and pass it as `after` on the next call.
3. If `hasMore` is true, call again with `next` until it is false.

Each reply is `{changes, next, hasMore}`. Each change has `id`, `calendarId`, `version`, `deleted` and, unless it was deleted, `event`. A change with `deleted: true` means the event is gone. A change's identity is `(id, calendarId)`, and the same `id` can appear in several calendars. A moved event shows up as a deletion of the old ID and a new row for the new ID. A moved event whose `id` stays the same shows up as a deletion for the old `calendarId` and an upsert for the new one. The deletion has the lower `version`, so apply changes in `version` order.

`limit` is optional: default 500, at most 2000.

The window is fixed at 7 days back and 14 days ahead of the call. The server refreshes the mirror at each call, so changes appear when you call, not before. Events that age out of the window are dropped without a deletion, so a client keeps past events. Deletion rows are kept for 30 days.

If `after` is older than the oldest deletion row the server still has, the reply is `{reset: true}`. On `reset`, discard your copy of the events inside the window (7 days back to 14 days ahead) and resync from `after = 0`. Keep your past events. A `reset` also comes back when `after` is higher than the server's current offset, for example when the mirror file was recreated.

After you unblock a calendar or account, its older rows sit below your offset. A host that needs them should resync from `after = 0`.

## Permissions

macOS asks for Calendar access the first time a tool runs. The prompt names the app that launched the server, such as Terminal, your editor or the MCP client, not `macos-calendar-mcp`. Full access is required. Write-only access counts as denied.

If a tool returns "Calendar access is not granted":

1. Open System Settings, then Privacy & Security, then Calendars.
2. Turn on the app that runs the server. Use the app named in the earlier prompt.
3. Restart that app and try again.

If the app does not appear in the list, it may be missing the Calendars usage description that macOS requires. Run the server from an app that has one, such as Terminal.

## Known limitations

- A calendar whose identifier macOS drops during a full sync loses its block, because the block list uses that identifier.
- A calendar shared with you with edit rights looks like your own. EventKit does not expose an owner.
- Delegate calendars are not read.
- Changes reach a polling client at its next `get_changes` call, not at once.

## License

MIT. See [LICENSE](LICENSE).
