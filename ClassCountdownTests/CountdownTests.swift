import XCTest
@testable import ClassCountdown

// Checks the rules of the countdown with made-up events and a made-up clock.
final class CountdownTests: XCTestCase {

    // "Now" in all tests. The exact moment doesn't matter.
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    // An event that starts the given number of seconds after "now"
    // (negative: it has already started).
    func event(_ title: String = "Statistik", inSeconds seconds: TimeInterval,
               calendar: String = "University") -> ClassEvent {
        ClassEvent(title: title, start: now.addingTimeInterval(seconds),
                   location: nil, calendarName: calendar)
    }

    func text(inSeconds seconds: TimeInterval) -> String {
        Countdown.menuBarText(for: event(inSeconds: seconds), now: now)
    }

    // MARK: - When something is shown

    func testNothingMoreThan30MinutesBefore() {
        XCTAssertNil(Countdown.eventToShow([event(inSeconds: 30 * 60 + 1)], now: now))
    }

    func testAppearsExactly30MinutesBefore() {
        let e = event(inSeconds: 30 * 60)
        XCTAssertEqual(Countdown.eventToShow([e], now: now), e)
        XCTAssertEqual(text(inSeconds: 30 * 60), "30 min")
    }

    func testShowsNowAtStartForFiveMinutes() {
        XCTAssertEqual(text(inSeconds: 0), "now")
        XCTAssertEqual(text(inSeconds: -299), "now")
        XCTAssertNotNil(Countdown.eventToShow([event(inSeconds: 0)], now: now))
        XCTAssertNotNil(Countdown.eventToShow([event(inSeconds: -299)], now: now))
        XCTAssertNil(Countdown.eventToShow([event(inSeconds: -300)], now: now))
    }

    func testNoEventsShowsNothing() {
        XCTAssertNil(Countdown.eventToShow([], now: now))
    }

    // MARK: - The text

    func testRoundsMinutesUp() {
        XCTAssertEqual(text(inSeconds: 29 * 60 + 30), "30 min")
        XCTAssertEqual(text(inSeconds: 23 * 60), "23 min")
        XCTAssertEqual(text(inSeconds: 61), "2 min")
        XCTAssertEqual(text(inSeconds: 60), "1 min")
        XCTAssertEqual(text(inSeconds: 1), "1 min")
    }

    // MARK: - Which event

    func testEarliestStartWins() {
        let a = event("A", inSeconds: 10 * 60)
        let b = event("B", inSeconds: 5 * 60)
        XCTAssertEqual(Countdown.eventToShow([a, b], now: now), b)

        // A has started and still shows "now"; B starts in a minute.
        let started = event("A", inSeconds: -2 * 60)
        let soon = event("B", inSeconds: 60)
        XCTAssertEqual(Countdown.eventToShow([soon, started], now: now), started)

        // A's five minutes are over, so B takes its place.
        let over = event("A", inSeconds: -5 * 60)
        let stillNow = event("B", inSeconds: -3 * 60)
        XCTAssertEqual(Countdown.eventToShow([over, stillNow], now: now), stillNow)
    }

    func testTieIsBrokenByTitle() {
        let a = event("A", inSeconds: 600)
        let b = event("B", inSeconds: 600)
        XCTAssertEqual(Countdown.eventToShow([a, b], now: now), a)
        XCTAssertEqual(Countdown.eventToShow([b, a], now: now), a)
    }

    // MARK: - Which events count

    func testOnlyTheListedCalendars() {
        let wanted = ["University", "Classes"]
        XCTAssertEqual(Countdown.calendarNames, wanted)
        for name in wanted {
            XCTAssertNotNil(Countdown.eventToShow([event(inSeconds: 600, calendar: name)], now: now), name)
        }
        for name in ["Private", "university", "University ", ""] {
            XCTAssertNil(Countdown.eventToShow([event(inSeconds: 600, calendar: name)], now: now), name)
        }
    }

    func testParsesSettingsFile() {
        let text = "# my calendars\nUniversity\n\n  Classes  \n#Private\n"
        XCTAssertEqual(CalendarSettings.parse(text), ["University", "Classes"])
        XCTAssertEqual(CalendarSettings.parse(""), [])
        XCTAssertEqual(CalendarSettings.parse("\n \n# only a comment\n"), [])
    }

    func testIgnoresAllDayDeclinedCancelled() {
        var allDay = event(inSeconds: 600); allDay.isAllDay = true
        var declined = event(inSeconds: 600); declined.isDeclined = true
        var cancelled = event(inSeconds: 600); cancelled.isCancelled = true
        XCTAssertNil(Countdown.eventToShow([allDay, declined, cancelled], now: now))
    }

    // MARK: - The next event (for the status window)

    func testNextEvent() {
        let over = event("Over", inSeconds: -300)
        let wrongCalendar = event("Private", inSeconds: 60, calendar: "Private")
        let tomorrow = event("Tomorrow", inSeconds: 24 * 3600)
        let nextWeek = event("Next week", inSeconds: 6 * 24 * 3600)
        XCTAssertEqual(Countdown.nextEvent([nextWeek, over, wrongCalendar, tomorrow], now: now), tomorrow)
        XCTAssertNil(Countdown.nextEvent([over, wrongCalendar], now: now))
    }

    // MARK: - The menu lines

    func testDetailLine() {
        var e = event(inSeconds: 600)
        XCTAssertEqual(Countdown.detailLine(for: e, timeText: "10:15"), "10:15")
        e.location = "Room 2.03"
        XCTAssertEqual(Countdown.detailLine(for: e, timeText: "10:15"), "10:15 · Room 2.03")
        e.location = "  "
        XCTAssertEqual(Countdown.detailLine(for: e, timeText: "10:15"), "10:15")
        e.location = "Room 2.03\nFallenbrunnen 3"
        XCTAssertEqual(Countdown.detailLine(for: e, timeText: "10:15"), "10:15 · Room 2.03")
    }

    func testDisplayTitle() {
        XCTAssertEqual(Countdown.displayTitle(event("Statistik", inSeconds: 0)), "Statistik")
        XCTAssertEqual(Countdown.displayTitle(event("", inSeconds: 0)), "(No title)")
        XCTAssertEqual(Countdown.displayTitle(event("  ", inSeconds: 0)), "(No title)")
    }
}
