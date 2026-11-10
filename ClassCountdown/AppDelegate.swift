import AppKit
import SwiftUI

// Owns the countdown in the menu bar. Every few seconds it asks the
// calendar for the events around now, lets Countdown decide what to show,
// and shows or hides the menu bar item accordingly.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // The item in the menu bar. It is hidden most of the time.
    var statusItem: NSStatusItem!

    let calendar = CalendarReader()

    // Fires every few seconds to bring the menu bar up to date.
    var timer: Timer?

    // The small window shown when the app is opened again while running.
    var statusWindow: NSWindow?

    // What the menu bar showed last. The item is only touched when this
    // changes, so an open menu is not replaced every few seconds.
    private var lastShown = ""

    // Our request to macOS not to slow the app down (see below).
    private var napGuard: NSObjectProtocol?

    // True while the automated tests run. Then the app must leave the real
    // calendar, the login items and other running copies alone.
    private let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = false
        // Digits that all have the same width, so the item doesn't wobble
        // when "20 min" becomes "19 min".
        statusItem.button?.font = .monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.button?.imagePosition = .imageLeading

        if isRunningTests { return }

        // Use the calendar names from the settings file on this Mac.
        Countdown.calendarNames = CalendarSettings.load()

        // Only one copy may run; this one replaces any older copy.
        SingleInstance.quitOlderCopies()

        // The first time an installed copy runs, add it to the login items.
        let defaults = UserDefaults.standard
        if LoginItem.shouldEnableAutomatically(bundlePath: Bundle.main.bundlePath,
                                               alreadyDone: defaults.bool(forKey: "didSetUpLoginItem")) {
            // Remember it only if it worked, so a failed try is repeated next time.
            if LoginItem.setEnabled(true) {
                defaults.set(true, forKey: "didSetUpLoginItem")
            }
        }

        // macOS slows down apps that show nothing on screen ("App Nap").
        // That could make the countdown appear late, so we ask it not to.
        napGuard = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Keeps the countdown on time")

        // Look at the calendar every 5 seconds. ".common" keeps the timer
        // running while a menu is open.
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            // Timers on the main run loop fire on the main thread.
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        Task {
            // The first time, macOS asks whether the app may read calendars.
            if calendar.access == .notAsked {
                await calendar.requestAccess()
            }
            refresh()
        }
    }

    // Reads the events around now and updates the menu bar.
    func refresh() {
        // While macOS is still showing its question, show nothing.
        guard calendar.access != .notAsked else { return }
        let now = Date()
        let events = calendar.events(from: now.addingTimeInterval(-Countdown.nowDuration),
                                     to: now.addingTimeInterval(Countdown.leadTime))
        show(event: Countdown.eventToShow(events, now: now), access: calendar.access, now: now)
    }

    // The one place that changes the menu bar item.
    func show(event: ClassEvent?, access: CalendarAccess, now: Date) {
        // First describe in one line what should be visible now.
        let shown: String
        if access == .denied {
            shown = "no calendar access"
        } else if let event {
            shown = Countdown.menuBarText(for: event, now: now) + " | "
                + Countdown.displayTitle(event) + " | " + detailLine(for: event)
        } else {
            shown = "hidden"
        }

        // Nothing new? Then leave the menu bar alone.
        if shown == lastShown { return }
        lastShown = shown
        NSLog("ClassCountdown menu bar: %@", shown)

        if access == .denied {
            // Without access the app would be invisible forever, so it
            // shows a warning symbol with a way to fix it.
            statusItem.button?.image = NSImage(systemSymbolName: "calendar.badge.exclamationmark",
                                               accessibilityDescription: "ClassCountdown: no calendar access")
            statusItem.button?.title = ""
            statusItem.menu = noAccessMenu()
            statusItem.isVisible = true
        } else if let event {
            statusItem.button?.image = NSImage(systemSymbolName: "graduationcap",
                                               accessibilityDescription: "Next class")
            statusItem.button?.title = " " + Countdown.menuBarText(for: event, now: now)
            statusItem.menu = eventMenu(for: event)
            statusItem.isVisible = true
        } else {
            statusItem.isVisible = false
            statusItem.menu = nil
        }
    }

    // "10:15 · Room 2.03": the start time in the Mac's own time format.
    private func detailLine(for event: ClassEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return Countdown.detailLine(for: event, timeText: formatter.string(from: event.start))
    }

    // MARK: - Menus

    // The menu under the countdown: event name, time and room, Quit.
    private func eventMenu(for event: ClassEvent) -> NSMenu {
        let menu = NSMenu()
        // Items without an action are grey and can't be clicked: plain text.
        menu.addItem(withTitle: Countdown.displayTitle(event), action: nil, keyEquivalent: "")
        menu.addItem(withTitle: detailLine(for: event), action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(quitItem())
        return menu
    }

    // The menu under the warning symbol.
    private func noAccessMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "ClassCountdown can't read your calendars", action: nil, keyEquivalent: "")
        let settings = NSMenuItem(title: "Open Privacy Settings…",
                                  action: #selector(openPrivacySettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quitItem())
        return menu
    }

    private func quitItem() -> NSMenuItem {
        NSMenuItem(title: "Quit ClassCountdown",
                   action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    // Opens System Settings > Privacy & Security > Calendars.
    @objc func openPrivacySettings() {
        let address = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        if let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Status window

    // Called when the user opens ClassCountdown while it is already running
    // (from Applications or Spotlight). Because the app is usually
    // invisible, this is the way to see that it runs, and to quit it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStatus()
        return true
    }

    func showStatus() {
        // Build the window anew each time, so the facts in it are current.
        statusWindow?.close()

        // The automated tests must not look at the real calendar, so they
        // get a window without calendar facts.
        let access: CalendarAccess = isRunningTests ? .denied : calendar.access
        let found = isRunningTests ? [] : calendar.foundCalendarNames()
        let view = StatusView(
            access: access,
            found: found,
            missing: Countdown.calendarNames.filter { !found.contains($0) },
            nextEventText: isRunningTests ? nil : nextEventText(),
            openPrivacySettings: { [weak self] in self?.openPrivacySettings() },
            quit: { NSApp.terminate(nil) }
        )

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "ClassCountdown"
        // We keep the window in statusWindow ourselves.
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        statusWindow = window

        // A background app has to step forward, or the window opens behind others.
        if !isRunningTests { NSApp.activate(ignoringOtherApps: true) }
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    // "Statistik, Tue 14:15" for the next event in the coming 7 days.
    private func nextEventText() -> String? {
        let now = Date()
        let events = calendar.events(from: now.addingTimeInterval(-Countdown.nowDuration),
                                     to: now.addingTimeInterval(7 * 24 * 3600))
        guard let next = Countdown.nextEvent(events, now: now) else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE HH:mm")
        return "\(Countdown.displayTitle(next)), \(formatter.string(from: next.start))"
    }
}
