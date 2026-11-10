import EventKit

// Whether the app may read the calendars.
enum CalendarAccess {
    case notAsked   // macOS has not shown its question yet
    case granted
    case denied     // refused, or only "add events" was allowed
}

// The only file that talks to the Mac's calendars (through EventKit).
// It only reads. Everything it returns is a plain ClassEvent, so the
// rest of the app never sees the real calendar.
@MainActor
final class CalendarReader {

    private let store = EKEventStore()

    // The access we saw last time, to notice when it changes.
    private var lastAccess: CalendarAccess?

    var access: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notAsked
        case .fullAccess: return .granted
        default: return .denied
        }
    }

    // Makes macOS show its "allow access to your calendars?" question.
    // It only appears the first time; afterwards macOS remembers the answer.
    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
    }

    // The calendars on this Mac whose names are in our list.
    private func wantedCalendars() -> [EKCalendar] {
        store.calendars(for: .event).filter { Countdown.calendarNames.contains($0.title) }
    }

    // Which of the wanted calendar names exist on this Mac.
    func foundCalendarNames() -> [String] {
        let existing = Set(wantedCalendars().map(\.title))
        return Countdown.calendarNames.filter { existing.contains($0) }
    }

    // All events of the wanted calendars that touch the given time span.
    func events(from: Date, to: Date) -> [ClassEvent] {
        let access = self.access
        if access != lastAccess {
            // Access was just granted or taken away (for example in System
            // Settings). Tell the store to forget what it knew and look again.
            store.reset()
            lastAccess = access
        }
        guard access == .granted else { return [] }
        let calendars = wantedCalendars()
        // Careful: asking with an empty list would mean "all calendars".
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        return store.events(matching: predicate).map(Self.classEvent)
    }

    // Turns a real calendar event into our plain ClassEvent.
    static func classEvent(from event: EKEvent) -> ClassEvent {
        // "Declined" means: I am one of the invited people and said no.
        let declined = (event.attendees ?? []).contains {
            $0.isCurrentUser && $0.participantStatus == .declined
        }
        let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ClassEvent(
            title: event.title ?? "",
            start: event.startDate,
            location: location.isEmpty ? nil : location,
            calendarName: event.calendar?.title ?? "",
            isAllDay: event.isAllDay,
            isDeclined: declined,
            isCancelled: event.status == .canceled
        )
    }
}
