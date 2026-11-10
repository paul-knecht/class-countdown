import Foundation

// One calendar event, reduced to the few facts the countdown needs.
// It is a plain value with no link to the real calendar, so the logic
// in Countdown can be tested with made-up events.
struct ClassEvent: Equatable {
    var title: String
    var start: Date
    // The room or address. nil when the event has no location.
    var location: String?
    // The name of the calendar the event is in, for example "University".
    var calendarName: String
    var isAllDay = false
    // True if I was invited and answered "no".
    var isDeclined = false
    var isCancelled = false
}
