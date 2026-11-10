import SwiftUI

// The small window that appears when ClassCountdown is opened again while
// it is already running. It shows that the app works and what it watches.
struct StatusView: View {

    let access: CalendarAccess
    // Which of the wanted calendars exist on this Mac, and which don't.
    let found: [String]
    let missing: [String]
    // For example "Statistik, Tue 14:15". nil if nothing is coming up.
    let nextEventText: String?

    // What the buttons do. AppDelegate passes these in.
    let openPrivacySettings: () -> Void
    let quit: () -> Void

    @State private var startAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ClassCountdown is running.")
                .font(.headline)

            if access == .granted {
                Text("The countdown appears in the menu bar 30 minutes before an event.")

                Text(found.isEmpty
                     ? "None of the calendars it looks for exist on this Mac."
                     : "Watching: " + found.joined(separator: ", "))
                if !missing.isEmpty {
                    Text("Not found on this Mac: " + missing.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }

                Text(nextEventText.map { "Next: " + $0 } ?? "No matching event in the next 7 days.")
            } else {
                Text("It can't read your calendars, so it can't show a countdown.")
                Button("Open Privacy Settings…", action: openPrivacySettings)
                Text("Switch ClassCountdown on under Calendars and choose Full Access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Toggle("Start ClassCountdown when I log in", isOn: $startAtLogin)
                .onChange(of: startAtLogin) { _, wanted in
                    // If macOS refuses the change, show the real state again.
                    if !LoginItem.setEnabled(wanted) {
                        startAtLogin = LoginItem.isEnabled
                    }
                }

            HStack {
                Spacer()
                Button("Quit ClassCountdown", action: quit)
            }

            Text("To see this window again, open ClassCountdown from Applications or Spotlight.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 400)
    }
}
