import XCTest
@testable import ClassCountdown

// Checks the running app: the menu bar item and the status window.
// The tests hand the app made-up events; the real calendar is not touched.
@MainActor
final class SmokeTests: XCTestCase {

    let now = Date(timeIntervalSince1970: 1_800_000_000)

    var delegate: AppDelegate { NSApp.delegate as! AppDelegate }

    override func tearDown() async throws {
        // Leave the menu bar empty after each test.
        delegate.show(event: nil, access: .granted, now: now)
    }

    func testAppDelegateExists() {
        XCTAssertTrue(NSApp.delegate is AppDelegate)
    }

    func testShowsCountdown() throws {
        let event = ClassEvent(title: "Statistik", start: now.addingTimeInterval(23 * 60),
                               location: "Room 2.03", calendarName: "University")
        delegate.show(event: event, access: .granted, now: now)

        XCTAssertTrue(delegate.statusItem.isVisible)
        XCTAssertEqual(delegate.statusItem.button?.title, " 23 min")
        XCTAssertNotNil(delegate.statusItem.button?.image)

        let titles = try XCTUnwrap(delegate.statusItem.menu).items.map(\.title)
        XCTAssertEqual(titles.first, "Statistik")
        XCTAssertTrue(titles[1].hasSuffix(" · Room 2.03"), titles[1])
        XCTAssertEqual(titles.last, "Quit ClassCountdown")
    }

    func testShowsNowAfterStart() {
        let event = ClassEvent(title: "Statistik", start: now.addingTimeInterval(-60),
                               location: nil, calendarName: "University")
        delegate.show(event: event, access: .granted, now: now)
        XCTAssertEqual(delegate.statusItem.button?.title, " now")
    }

    func testHiddenWithoutEvent() {
        delegate.show(event: nil, access: .granted, now: now)
        XCTAssertFalse(delegate.statusItem.isVisible)
    }

    // Without calendar access the app must not be invisible: it shows a
    // warning symbol with a way to the right settings page.
    func testDeniedShowsWarning() throws {
        delegate.show(event: nil, access: .denied, now: now)
        XCTAssertTrue(delegate.statusItem.isVisible)
        XCTAssertEqual(delegate.statusItem.button?.title, "")
        let titles = try XCTUnwrap(delegate.statusItem.menu).items.map(\.title)
        XCTAssertTrue(titles.contains("Open Privacy Settings…"))
        XCTAssertEqual(titles.last, "Quit ClassCountdown")
    }

    // The tests must never start the real calendar check.
    func testNoTimerDuringTests() {
        XCTAssertNil(delegate.timer)
    }

    // Opening the app again while it runs shows the status window.
    func testOpeningTheAppAgainShowsStatusWindow() throws {
        XCTAssertNil(delegate.statusWindow)
        _ = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
        let window = try XCTUnwrap(delegate.statusWindow)
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(window.title, "ClassCountdown")
        window.close()
        delegate.statusWindow = nil
    }
}
