import Foundation

// All the rules of the app: which event is shown, when, and with what text.
// Nothing in here talks to the calendar or the menu bar, so every rule
// can be checked by a test.
enum Countdown {

    // Example calendar names, used until you list your own in the
    // settings file (see CalendarSettings.swift).
    static let exampleCalendarNames = ["University", "Classes"]

    // Only events from calendars with exactly these names are shown.
    // The app replaces this with the names from the settings file at launch.
    static var calendarNames = exampleCalendarNames

    // The countdown appears this long before an event starts (in seconds).
    static let leadTime: TimeInterval = 30 * 60

    // After the start, "now" stays this long (in seconds).
    static let nowDuration: TimeInterval = 5 * 60

    // Is this an event we care about at all?
    static func isWanted(_ event: ClassEvent) -> Bool {
        calendarNames.contains(event.calendarName)
            && !event.isAllDay && !event.isDeclined && !event.isCancelled
    }

    // The event the menu bar should show right now, or nil for "show nothing".
    // An event is shown from 30 minutes before its start until 5 minutes
    // after its start. If several qualify, the one that starts first wins.
    static func eventToShow(_ events: [ClassEvent], now: Date) -> ClassEvent? {
        let showable = events.filter { event in
            isWanted(event)
                && now >= event.start.addingTimeInterval(-leadTime)
                && now < event.start.addingTimeInterval(nowDuration)
        }
        return earliest(showable)
    }

    // The next event we care about, however far away it is.
    // Used by the status window ("Next: …").
    static func nextEvent(_ events: [ClassEvent], now: Date) -> ClassEvent? {
        let coming = events.filter { event in
            isWanted(event) && now < event.start.addingTimeInterval(nowDuration)
        }
        return earliest(coming)
    }

    // The event that starts first. If two start at the same moment, the
    // title decides, so the choice doesn't flip back and forth.
    private static func earliest(_ events: [ClassEvent]) -> ClassEvent? {
        events.min { a, b in
            a.start != b.start ? a.start < b.start : a.title < b.title
        }
    }

    // The text in the menu bar: "23 min", or "now" once the event has started.
    // Minutes are rounded up, so 30 seconds before the start it says "1 min"
    // and never "0 min".
    static func menuBarText(for event: ClassEvent, now: Date) -> String {
        let secondsLeft = event.start.timeIntervalSince(now)
        if secondsLeft <= 0 { return "now" }
        let minutes = Int((secondsLeft / 60).rounded(.up))
        return "\(minutes) min"
    }

    // The event's name for the menu. Events without a name get a stand-in.
    static func displayTitle(_ event: ClassEvent) -> String {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "(No title)" : title
    }

    // The second line of the menu: the start time, plus the room if there
    // is one. Only the first line of the location is used, because calendar
    // locations often continue with a full address.
    // The time arrives already formatted ("10:15"), so this function does
    // not depend on the Mac's language settings.
    static func detailLine(for event: ClassEvent, timeText: String) -> String {
        let firstLine = (event.location ?? "")
            .components(separatedBy: .newlines).first ?? ""
        let room = firstLine.trimmingCharacters(in: .whitespaces)
        return room.isEmpty ? timeText : "\(timeText) · \(room)"
    }
}
