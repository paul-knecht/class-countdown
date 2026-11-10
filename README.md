# ClassCountdown

A small macOS menu bar app. Thirty minutes before a university event
starts, a countdown appears in the menu bar (`23 min`). When the event
starts it says `now` for five minutes, then it disappears again. The rest
of the time there is nothing in the menu bar.

Click the countdown to see the event's name, start time and room, and to
quit the app.

## Which events count

Only events in the calendars you list count. All-day, declined and
cancelled events are ignored.

The list is a small text file on your Mac, one calendar name per line:

```
~/Library/Application Support/ClassCountdown/calendars.txt
```

The app creates it with two example names (`University`, `Classes`) the
first time it starts. Put in the exact names of your own calendars and
start ClassCountdown again.

## Install

```bash
./scripts/install.sh
```

This builds the app, copies it to `/Applications` and starts it. The first
time, macOS asks whether ClassCountdown may access your calendars: choose
**Allow Full Access**. The app only reads; it never changes a calendar.
The app adds itself to the login items, so it starts with the Mac.

## The app is invisible. Is it running? How do I quit it?

Open ClassCountdown again from Applications or Spotlight. A small window
shows whether it can read your calendars, which of the calendars it found,
the next event it will count down to, a switch for "start when I log in",
and a Quit button.

If the menu bar shows a calendar symbol with an exclamation mark, the app
has no calendar access. Click it and choose "Open Privacy Settings…", then
switch ClassCountdown on under Calendars with Full Access.

## Tests

```bash
xcodebuild -project ClassCountdown.xcodeproj -scheme ClassCountdown -derivedDataPath build test
```

The rules (which event, what text, when to hide) live in
`ClassCountdown/Countdown.swift` and are tested without real calendars in
`ClassCountdownTests/CountdownTests.swift`.

## Licence

MIT, see [LICENSE](LICENSE).
