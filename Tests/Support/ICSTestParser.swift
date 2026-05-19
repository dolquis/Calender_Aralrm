import Foundation

/// Minimal iCalendar parser used only in tests (η-I2).
/// Handles v1 output: UTC timestamps, no VTIMEZONE, CRLF line endings.
enum ICSTestParser {
    struct ParsedICSEvent: Equatable {
        let uid: String
        let summary: String
        let dtstart: Date
        let dtend: Date
    }

    enum ParseError: Error {
        case malformedLine(String)
        case missingField(String)
        case badDate(String)
    }

    static func parse(_ text: String) throws -> [ParsedICSEvent] {
        let lines = unfoldContentLines(text.components(separatedBy: "\r\n"))
        var events: [ParsedICSEvent] = []
        var inEvent = false
        var uid = ""
        var summary = ""
        var dtstart: Date?
        var dtend: Date?

        for line in lines {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                uid = ""; summary = ""; dtstart = nil; dtend = nil
            } else if line == "END:VEVENT", inEvent {
                guard !uid.isEmpty else { throw ParseError.missingField("UID") }
                guard !summary.isEmpty else { throw ParseError.missingField("SUMMARY") }
                guard let s = dtstart else { throw ParseError.missingField("DTSTART") }
                guard let e = dtend else { throw ParseError.missingField("DTEND") }
                events.append(ParsedICSEvent(uid: uid, summary: summary, dtstart: s, dtend: e))
                inEvent = false
            } else if inEvent {
                if line.hasPrefix("UID:") {
                    uid = String(line.dropFirst(4))
                } else if line.hasPrefix("SUMMARY:") {
                    summary = unescapeText(String(line.dropFirst(8)))
                } else if line.hasPrefix("DTSTART:") {
                    dtstart = try parseUTCDate(String(line.dropFirst(8)))
                } else if line.hasPrefix("DTEND:") {
                    dtend = try parseUTCDate(String(line.dropFirst(6)))
                }
            }
        }
        return events
    }

    private static func unfoldContentLines(_ lines: [String]) -> [String] {
        var unfolded: [String] = []
        for line in lines where !line.isEmpty {
            if let first = line.first, first == " " || first == "\t" {
                guard let last = unfolded.indices.last else { continue }
                unfolded[last] += line.dropFirst()
            } else {
                unfolded.append(line)
            }
        }
        return unfolded
    }

    private static func parseUTCDate(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")!
        formatter.calendar = Calendar(identifier: .gregorian)
        guard let date = formatter.date(from: value) else {
            throw ParseError.badDate(value)
        }
        return date
    }

    private static func unescapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
