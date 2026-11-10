import Foundation

// Reads the list of calendar names from a small text file on this Mac,
// so the list is personal and never part of the source code.
//
// The file is  ~/Library/Application Support/ClassCountdown/calendars.txt
// with one calendar name per line. Empty lines and lines starting with #
// are ignored.
enum CalendarSettings {

    // Where the settings file lives.
    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClassCountdown")
            .appendingPathComponent("calendars.txt")
    }

    // Turns the text of the file into a list of names.
    static func parse(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    // The names from the file. If the file is missing or lists nothing,
    // the example names are used and written to a new file, so there is
    // something to edit.
    static func load() -> [String] {
        if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            let names = parse(text)
            if !names.isEmpty { return names }
        } else {
            writeExampleFile()
        }
        return Countdown.exampleCalendarNames
    }

    // Creates the file with the example names, if there is none yet.
    private static func writeExampleFile() {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let text = "# One calendar name per line. Restart ClassCountdown after changing this file.\n"
            + Countdown.exampleCalendarNames.joined(separator: "\n") + "\n"
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
