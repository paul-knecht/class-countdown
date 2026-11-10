# ClassCountdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A menu bar app that shows "N min" for the 30 minutes before a university event and "now" for 5 minutes after its start, and is otherwise invisible.

**Architecture:** Pure value type `ClassEvent` and pure functions in `Countdown` decide what to show; `CalendarReader` is the only EventKit code; `AppDelegate` runs a 5-second timer and shows or hides one `NSStatusItem`. A small SwiftUI window (`StatusView`) appears when the app is opened again.

**Tech Stack:** Swift 5, AppKit, SwiftUI, EventKit, ServiceManagement, XCTest. Xcode 27.2, macOS 14+ deployment target.

**Spec:** `docs/superpowers/specs/2026-11-10-class-countdown-design.md`

## Global Constraints

- Project layout copied from `~/Developer/glance` (`Glance.xcodeproj`): hand-written `project.pbxproj` with file-system-synchronised groups, hosted test target, shared scheme. Replace `Glance` → `ClassCountdown`, `local.glance` → `local.classcountdown`, object-ID prefix `BB` → `CC`.
- `LSUIElement = YES`, no sandbox, ad-hoc signing, no third-party code.
- Info.plist key `NSCalendarsFullAccessUsageDescription` = "ClassCountdown reads your calendars to show a countdown before your university events. It never changes them."
- Calendar names, exactly: `University`, `Classes`, `Study`, `Campus Events`, `Timetable`, `Timetable II`. Lead time 30 min, "now" 5 min, refresh every 5 s.
- Code style: simple, short comments in plain language explaining why (as in Glance). Beginner reads this code.
- While tests run (`XCTestConfigurationFilePath` set) the app does not ask for calendar access, start the timer, quit other copies or touch login items.
- Every commit message ends with the `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>` line. Work on `feature/countdown`.

## Review Focus

1. Event starts exactly now / exactly 30 min away / exactly 5 min ago: boundaries are start−30 min inclusive, start+5 min exclusive (tested in Task 2).
2. Event with empty title or location that is only whitespace or has several lines: menu shows "(No title)", no dangling " · ", only the first location line (tested in Task 2).
3. Calendar access revoked or granted while the app runs: the warning symbol appears / disappears within one refresh (manual, Task 5).
4. Mac asleep across an event start: after waking, the next refresh shows the right state; nothing stale stays in the menu bar (by construction: state is recomputed from the clock every tick; manual).
5. None of the six calendars exists on this Mac: app is invisible, but the status window says which were not found (manual, Task 5).

---

### Task 1: Project skeleton that builds and tests

**Files:**
- Create: `ClassCountdown.xcodeproj/project.pbxproj`, `ClassCountdown.xcodeproj/xcshareddata/xcschemes/ClassCountdown.xcscheme` (from Glance, see Global Constraints; add `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` to both app configurations)
- Create: `ClassCountdown/main.swift` (as Glance), `ClassCountdown/AppDelegate.swift` (empty `@MainActor class AppDelegate: NSObject, NSApplicationDelegate`)
- Create: `ClassCountdown/SingleInstance.swift`, `ClassCountdown/LoginItem.swift` (copied from Glance, names changed)
- Test: `ClassCountdownTests/SmokeTests.swift` (`NSApp.delegate is AppDelegate`), `SingleInstanceTests.swift`, `LoginItemTests.swift` (copied from Glance, names changed)

- [ ] Write files.
- [ ] Run `xcodebuild -project ClassCountdown.xcodeproj -scheme ClassCountdown -derivedDataPath build test`. Expected: `** TEST SUCCEEDED **`.
- [ ] Check the built Info.plist contains `NSCalendarsFullAccessUsageDescription` (`plutil -p build/Build/Products/Debug/ClassCountdown.app/Contents/Info.plist`). If the generated plist drops the key, add a partial `ClassCountdown-Info.plist` outside the synchronised folder and set `INFOPLIST_FILE`.
- [ ] Commit: "Add Xcode project skeleton with single-copy and login item helpers".

### Task 2: Pure countdown logic

**Files:**
- Create: `ClassCountdown/ClassEvent.swift`, `ClassCountdown/Countdown.swift`
- Test: `ClassCountdownTests/CountdownTests.swift`

**Interfaces (produced):**

```swift
struct ClassEvent: Equatable {
    var title: String
    var start: Date
    var location: String?      // nil when the event has no location
    var calendarName: String
    var isAllDay = false
    var isDeclined = false
    var isCancelled = false
}

enum Countdown {
    static let calendarNames: [String]            // the six names
    static let leadTime: TimeInterval = 30 * 60
    static let nowDuration: TimeInterval = 5 * 60

    static func isWanted(_ event: ClassEvent) -> Bool          // right calendar, not all-day/declined/cancelled
    static func eventToShow(_ events: [ClassEvent], now: Date) -> ClassEvent?
    static func nextEvent(_ events: [ClassEvent], now: Date) -> ClassEvent?   // earliest wanted event with start+nowDuration > now; for the status window
    static func menuBarText(for event: ClassEvent, now: Date) -> String       // "23 min" or "now"
    static func displayTitle(_ event: ClassEvent) -> String                   // trimmed title or "(No title)"
    static func detailLine(for event: ClassEvent, timeText: String) -> String // "10:15 · Room 2.03" or "10:15"
}
```

`detailLine` takes the already formatted time so tests do not depend on the Mac's locale.

- [ ] **Write failing tests** (base time `t0 = Date(timeIntervalSince1970: 1_800_000_000)`, helper `event(_ title:, in minutes: Double, calendar: = "University")`):
  - `testNothingMoreThan30MinutesBefore`: start in 30 min + 1 s → `nil`.
  - `testAppearsExactly30MinutesBefore`: start in 30 min → shown, text `"30 min"`.
  - `testRoundsMinutesUp`: 29 min 30 s left → `"30 min"`; 23 min exactly → `"23 min"`; 61 s → `"2 min"`; 60 s → `"1 min"`; 1 s → `"1 min"`.
  - `testShowsNowAtStartForFiveMinutes`: 0 s → `"now"`; started 4 min 59 s ago → shown, `"now"`; started 5 min ago → `nil`.
  - `testEarliestStartWins`: A in 10 min, B in 5 min → B; A started 2 min ago, B in 1 min → A; A started 5 min ago, B started 3 min ago → B.
  - `testTieIsBrokenByTitle`: same start, titles "B", "A" in either input order → "A".
  - `testOnlyTheSixCalendars`: each of the six names is shown; `"Private"`, `"university"`, `"University "` are not.
  - `testIgnoresAllDayDeclinedCancelled`: each flag alone → `nil`.
  - `testNextEvent`: skips unwanted events and ones whose "now" window has passed; returns earliest remaining, however far ahead.
  - `testDetailLine`: location `nil` → `"10:15"`; `"Room 2.03"` → `"10:15 · Room 2.03"`; `"  "` → `"10:15"`; `"Room 2.03\nFallenbrunnen 3"` → `"10:15 · Room 2.03"`.
  - `testDisplayTitle`: `"Statistik"` → same; `""` and `"  "` → `"(No title)"`.
- [ ] Run tests, see them fail to compile. Implement. Minutes = `Int(ceil(secondsLeft / 60))`; `secondsLeft <= 0` → `"now"`.
- [ ] Run tests: all pass. Commit: "Add tested countdown logic: which event to show and what text".

### Task 3: Reading the calendar

**Files:**
- Create: `ClassCountdown/CalendarReader.swift`

**Interfaces (produced):**

```swift
enum CalendarAccess { case notAsked, granted, denied }   // writeOnly and restricted count as denied

@MainActor
final class CalendarReader {
    var access: CalendarAccess { get }                    // from EKEventStore.authorizationStatus(for: .event)
    func requestAccess() async                            // requestFullAccessToEvents; errors ignored
    func events(from: Date, to: Date) -> [ClassEvent]     // [] unless granted; only calendars in Countdown.calendarNames
    func foundCalendarNames() -> [String]                 // which of Countdown.calendarNames exist here, in list order
    static func classEvent(from event: EKEvent) -> ClassEvent
}
```

- Declined: `event.attendees` contains one with `isCurrentUser` and `participantStatus == .declined`. Cancelled: `event.status == .canceled`. Empty/whitespace location → `nil`.
- If no wanted calendar exists, `events` returns `[]` without querying (a predicate with an empty calendar list would mean "all calendars").
- No unit tests: this file needs real calendars. It is kept thin for that reason. `xcodebuild build` must succeed.
- [ ] Implement, build, commit: "Read events from the wanted calendars with EventKit".

### Task 4: Menu bar item

**Files:**
- Modify: `ClassCountdown/AppDelegate.swift`
- Test: `ClassCountdownTests/SmokeTests.swift`

**Interfaces (produced):** `AppDelegate.show(event: ClassEvent?, access: CalendarAccess, now: Date)`: the one place that updates the status item, called by the timer (`refresh()`) and by tests.

Behaviour:
- `access == .denied` → item visible, image `calendar.badge.exclamationmark`, no title; menu: disabled "ClassCountdown can't read your calendars", "Open Privacy Settings…" (opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars`), separator, "Quit ClassCountdown".
- event present → item visible, image `graduationcap`, title `" " + menuBarText`; menu: disabled `displayTitle`, disabled `detailLine` (time via `DateFormatter` with `timeStyle = .short`), separator, "Quit ClassCountdown".
- otherwise → `statusItem.isVisible = false`.
- Use a monospaced-digit menu bar font so the width does not jump each minute.
- `applicationDidFinishLaunching`: unless tests are running: `SingleInstance.quitOlderCopies()`, login item auto-enable (Glance logic, key `didSetUpLoginItem`), request access if `.notAsked`, then `refresh()` and a repeating 5 s timer (added to `.common` run loop mode so it also runs while a menu is open). `refresh()` reads events from `now − nowDuration` to `now + leadTime`.
- Log one line with `NSLog` whenever the shown text changes (helps checking the installed app).

- [ ] **Failing smoke tests:** `testShowsCountdown` (event in 23 min, `.granted` → `statusItem.isVisible`, button title contains `"23 min"`, first menu item title is the event title, last is "Quit ClassCountdown"); `testHiddenWithoutEvent`; `testDeniedShowsWarning` (visible, menu contains "Open Privacy Settings…"). Each test ends by calling `show(event: nil, access: .granted, now:)`.
- [ ] Implement, run all tests, commit: "Show the countdown in the menu bar and hide it otherwise".

### Task 5: Status window, install script, README

**Files:**
- Create: `ClassCountdown/StatusView.swift`, `scripts/install.sh` (from Glance; reset hint `tccutil reset Calendar local.classcountdown`), `README.md`
- Modify: `ClassCountdown/AppDelegate.swift` (`applicationShouldHandleReopen` → `showStatus()`; window built fresh each time so its facts are current)
- Test: `SmokeTests.testOpeningTheAppAgainShowsStatusWindow`

`StatusView` takes plain values: `access: CalendarAccess`, `found: [String]`, `missing: [String]`, `nextEventText: String?`, `openPrivacySettings`, `quit`. It shows: headline "ClassCountdown is running."; access line; "Watching: …" and, if any, "Not found on this Mac: …"; "Next: Title, Tue 14:15" or "No matching event in the next 7 days."; the login toggle (Glance code); Quit button; footnote on how to reopen the window.

- [ ] Implement, tests pass, commit: "Add status window, install script and README".
- [ ] Tell the user about the calendar prompt, then run `./scripts/install.sh`. Manual checks: countdown with a test event (with the user's permission, removed afterwards), menu content, hidden otherwise, status window, login item registered (`sfltool dumpbtm` or the window's toggle).

### Task 6: Review and merge

- [ ] One independent review of `main..feature/countdown` against spec; fix what matters; re-run tests.
- [ ] `git checkout main && git merge --no-ff feature/countdown`.
