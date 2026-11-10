# ClassCountdown: design

Date: 2026-11-10. Working name: ClassCountdown (may be renamed).

## What it is for

A countdown in the macOS menu bar that appears shortly before a university
event starts, so there is no need to open the calendar to see how much time
is left. When nothing is about to start, the menu bar stays empty.

## Decided (agreed in conversation)

- The countdown appears 30 minutes before an event starts.
- Minutes only, no seconds. The menu bar shows only the time left, not the
  event name.
- Clicking it shows the event name, the start time, the room if the event
  has a location, and "Quit".
- Only events from calendars named exactly `University`, `Classes`, `Study`,
  `Campus Events`, `Timetable`, `Timetable II`.
- Outside the 30 minutes nothing is in the menu bar.
- When the event starts it shows "now" for five minutes, then disappears or
  switches to the next event.
- All-day events and declined events are ignored. If two events are close
  together, the one that starts first is shown.
- The calendar list is fixed in the code, in one obvious constant.
- The app starts with the Mac.
- It only reads calendars (EventKit). macOS asks once for calendar access.

## Non-goals for version 1

No settings for the calendar list or the times, no notifications or sounds,
no seconds, no event name in the menu bar, no editing of calendars, no
network access.

## Builder's calls (not discussed, can be changed)

1. **Menu bar text.** A small graduation cap symbol followed by the text:
   `30 min` … `2 min`, `1 min`, then `now`. The symbol makes the bare
   number recognisable among other menu bar items.
2. **Rounding.** Minutes are rounded up: with 29 min 30 s left it shows
   `30 min`, with 30 s left `1 min`. `now` appears exactly at the start
   time. So it never shows `0 min`, and never promises more time than
   there is by more than a minute.
3. **Which event.** An event is "showable" from 30 minutes before its start
   until 5 minutes after its start. Of all showable events, the one with
   the earliest start wins (ties: alphabetical by title, so the choice is
   stable). Example: A at 10:00 and B at 10:02: A is shown until 10:05
   (`now` from 10:00), then B shows `now` until 10:07.
4. **Other ignored events.** Cancelled events are ignored too. "Declined"
   means: the event has attendees and the current user's reply is
   "declined". The event's end time plays no role.
5. **Menu content.** Line 1: event title (grey, not clickable). Line 2:
   start time in the Mac's time format, then ` · ` and the first line of
   the location if there is one. Then a divider and "Quit ClassCountdown".
6. **No calendar access.** If access is denied (or only "add events"
   access is given), the menu bar permanently shows a calendar symbol with
   an exclamation mark. Its menu says "ClassCountdown can't read your
   calendars", offers "Open Privacy Settings…" (opens System Settings >
   Privacy & Security > Calendars) and "Quit ClassCountdown". As soon as
   access is granted the symbol goes away.
7. **Seeing and quitting the app while it is invisible.** Opening
   ClassCountdown again (Applications, Spotlight) while it runs shows a
   small window with: whether calendar access is granted; which of the six
   calendars were found on this Mac and which were not; the next matching
   event in the coming 7 days (or that there is none); a "Start
   ClassCountdown when I log in" switch; and a "Quit" button. This is also
   how to tell that the app is running and looking at the right calendars.
8. **Launch at login.** macOS's own login item service (`SMAppService`),
   switched on automatically the first time a copy inside an Applications
   folder runs, the same way Glance does it. It appears under System
   Settings > General > Login Items and can be switched off there or in
   the window from point 7.
9. **Single copy.** A newly started copy asks older copies to quit (Glance
   pattern).
10. **Keeping up to date.** The app re-reads the calendar and recomputes
    the text every 5 seconds. The window read is tiny (35 minutes), so
    this is cheap, and changes in the calendar and waking from sleep need
    no special handling. The text can be up to 5 seconds late.

## How it is built

Same setup as Glance and KeyPeek: hand-written Xcode project
`ClassCountdown.xcodeproj` with an app target and a hosted test target,
AppKit menu-bar-only app (`LSUIElement`), no sandbox, ad-hoc signing,
bundle identifier `local.classcountdown`, macOS 14 or later, no
third-party code. The Info.plist needs
`NSCalendarsFullAccessUsageDescription` (the sentence macOS shows in the
permission prompt).

Parts:

- `ClassEvent`: a plain value with title, start, location, calendar name,
  all-day flag, declined flag, cancelled flag. No EventKit types.
- `Countdown`: pure functions and the constants (calendar names, 30
  minutes, 5 minutes). `eventToShow(events, now)`, `menuBarText(event,
  now)`, `detailLine(event)`. Fully unit-tested with made-up events and
  times.
- `CalendarReader`: the only file that touches EventKit. Asks for access,
  reports the access state, turns `EKEvent`s into `ClassEvent`s, lists
  which of the wanted calendars exist.
- `AppDelegate`: owns the menu bar item, the 5-second timer and the menu;
  shows or hides the item from what `Countdown` returns.
- `StatusView`: the small window from point 7.
- `LoginItem`, `SingleInstance`: copied from Glance.
- `scripts/install.sh`: builds, installs to `/Applications`, starts it.

While the automated tests run, the app must not ask for calendar access,
start the timer or touch login items.

## Known limits

- Because the app is signed ad hoc, macOS treats each new build as a new
  app and asks for calendar access again after reinstalling.
- Two calendars with the same name in different accounts are both used.
- An event in more than one of the calendars may be found twice; the
  result is the same.

## Done means

Tests pass; the app is installed in `/Applications` and running; with
access granted, an event in one of the six calendars starting within 30
minutes makes the countdown appear and count down by the minute; clicking
shows the event name; otherwise nothing shows.
