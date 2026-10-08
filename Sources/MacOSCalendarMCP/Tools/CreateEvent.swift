import Foundation
import MCP

enum CreateEvent {
    static let definition = ToolDefinition(
        tool: Tool(
            name: "create_event",
            description: "Create an event. Without calendarId it goes into the Mac's default calendar.",
            inputSchema: Schema.object([
                "title": Schema.string("Event title"),
                "start": Schema.string("Start. \(Schema.date)"),
                "end": Schema.string("End. \(Schema.date)"),
                "calendarId": Schema.string("Calendar id from list_calendars. Must be editable."),
                "allDay": Schema.boolean("All-day event"),
                "location": Schema.string("Location"),
                "notes": Schema.string("Notes"),
                "url": Schema.string("Link, such as a video call URL"),
            ], required: ["title", "start", "end"])
        ),
        run: { args, context in
            let start = try args.date("start")
            let end = try args.date("end")
            guard end > start else { throw ToolError.invalidInput("end must be after start") }
            let draft = EventDraft(
                title: try args.string("title"), start: start, end: end,
                allDay: try args.optionalBool("allDay") ?? false, calendarId: try args.optionalString("calendarId"),
                location: try args.optionalString("location"), notes: try args.optionalString("notes"),
                url: try args.optionalString("url").flatMap(URL.init(string:))
            )
            return try await context.source.create(draft, among: await context.visibleCalendars())
        }
    )
}
