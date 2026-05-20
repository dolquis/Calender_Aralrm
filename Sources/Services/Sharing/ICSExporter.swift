import Foundation
import CryptoKit

// MARK: - Protocol

public protocol ICalendarExporting: Sendable {
    func export(
        range: ClosedRange<Date>,
        resolvedDays: [ResolvedDay],
        presets: [UUID: ShiftPresetSnapshot],
        calendar: Calendar,
        timeZone: TimeZone,
        now: Date
    ) -> String
}

// MARK: - Exporter

/// Generates RFC 5545 iCalendar text from resolved shift days.
///
/// v1 uses UTC (Z-suffix) timestamps to ensure compatibility across
/// Apple Calendar, Google Calendar, and Outlook without a VTIMEZONE block.
public struct ICSExporter: ICalendarExporting, Sendable {
    public init() {}

    public func export(
        range: ClosedRange<Date>,
        resolvedDays: [ResolvedDay],
        presets: [UUID: ShiftPresetSnapshot],
        calendar: Calendar,
        timeZone: TimeZone,
        now: Date
    ) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//ShiftAlarm//ja//EN",
            "CALSCALE:GREGORIAN",
            "X-WR-CALNAME:ShiftAlarm Export",
            "X-WR-TIMEZONE:\(timeZone.identifier)",
        ]

        var exportCalendar = calendar
        exportCalendar.timeZone = timeZone
        let dtstamp = Self.utcString(from: now)
        var cursor = exportCalendar.startOfDay(for: range.lowerBound)

        for resolved in resolvedDays {
            defer {
                cursor = exportCalendar.date(byAdding: .day, value: 1, to: cursor)!
            }

            // Must have a preset, a fire time, and not skip the alarm
            guard !resolved.skipsAlarm,
                  let presetID = resolved.presetID,
                  let preset = presets[presetID],
                  let alarmTime = resolved.fireTime,
                  let alarmHour = alarmTime.hour,
                  let alarmMinute = alarmTime.minute
            else { continue }

            // Build local Date for the alarm moment then convert to UTC
            var comps = exportCalendar.dateComponents([.year, .month, .day], from: cursor)
            comps.hour = alarmHour
            comps.minute = alarmMinute
            comps.second = 0
            comps.timeZone = timeZone
            guard let alarmDate = exportCalendar.date(from: comps) else { continue }
            let endDate = alarmDate.addingTimeInterval(30 * 60)

            let uid = Self.deterministicUID(date: cursor, presetID: presetID)
            lines += [
                "BEGIN:VEVENT",
                "UID:\(uid)",
                "DTSTAMP:\(dtstamp)",
                "DTSTART:\(Self.utcString(from: alarmDate))",
                "DTEND:\(Self.utcString(from: endDate))",
                "SUMMARY:\(Self.escapeText(preset.name))",
                "END:VEVENT",
            ]
        }

        lines.append("END:VCALENDAR")
        return lines.flatMap { Self.foldContentLine($0) }.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Write helpers

    public func write(text: String, toTemporaryFileNamed filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Internal helpers

    static func utcString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")!
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: date)
    }

    static func deterministicUID(date: Date, presetID: UUID) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")!
        let dateStr = formatter.string(from: date)
        let raw = "\(dateStr)|\(presetID.uuidString)"
        let hash = SHA256.hash(data: Data(raw.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "\(hex)@shiftalarm.local"
    }

    static func escapeText(_ text: String) -> String {
        var escaped = ""
        let scalars = Array(text.unicodeScalars)
        var index = scalars.startIndex
        while index < scalars.endIndex {
            let scalar = scalars[index]
            switch scalar.value {
            case 0x5C:
                escaped += "\\\\"
            case 0x2C:
                escaped += "\\,"
            case 0x3B:
                escaped += "\\;"
            case 0x0D:
                let next = scalars.index(after: index)
                if next < scalars.endIndex, scalars[next].value == 0x0A {
                    index = next
                }
                escaped += "\\n"
            case 0x0A:
                escaped += "\\n"
            default:
                escaped.unicodeScalars.append(scalar)
            }
            index = scalars.index(after: index)
        }
        return escaped
    }

    static func foldContentLine(_ line: String, limit: Int = 75) -> [String] {
        guard line.utf8.count > limit else { return [line] }

        var folded: [String] = []
        var current = ""
        var currentOctets = 0

        for scalar in line.unicodeScalars {
            let scalarOctets = String(scalar).utf8.count
            if currentOctets + scalarOctets > limit, !current.isEmpty {
                folded.append(current)
                current = " "
                currentOctets = 1
            }
            current.unicodeScalars.append(scalar)
            currentOctets += scalarOctets
        }

        if !current.isEmpty {
            folded.append(current)
        }
        return folded
    }
}
