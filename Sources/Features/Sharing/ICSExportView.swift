import SwiftData
import SwiftUI

public struct ICSExportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var fileURL: URL?
    @State private var preparing = false
    @State private var errorMessage: String?
    @State private var monthCount: Int = 1

    public init() {}

    public var body: some View {
        Form {
            Section("ics.export.range_section") {
                Stepper(value: $monthCount, in: 1...12) {
                    Text(String(format: String(localized: "ics.export.months_label"), monthCount))
                }
            }
            Section("ics.export.summary_section") {
                Text("ics.export.description")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    prepare()
                } label: {
                    if preparing {
                        ProgressView()
                    } else {
                        Text("ics.export.create")
                    }
                }
                .disabled(preparing)

                if let url = fileURL {
                    ShareLink(item: url) {
                        Label("ics.export.share", systemImage: "square.and.arrow.up")
                    }
                }
                if let msg = errorMessage {
                    Text(msg)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("ics.export.nav_title")
    }

    private func prepare() {
        preparing = true
        errorMessage = nil
        fileURL = nil
        let input = DayResolverInputBuilder.make(context: modelContext, calendar: Calendar.current)
        do {
            fileURL = try buildICSFile(input: input, months: monthCount)
        } catch {
            errorMessage = error.localizedDescription
        }
        preparing = false
    }

    private func buildICSFile(input: DayResolverInput, months: Int) throws -> URL {
        let calendar = Calendar.current
        let now = Date.now
        let exportRange = ICSExportDateRange.make(today: now, months: months, calendar: calendar)
        let resolvedDays = exportRange.dates.map {
            DayResolver.resolve(date: $0, input: input)
        }

        let exporter = ICSExporter()
        let text = exporter.export(
            range: exportRange.range,
            resolvedDays: resolvedDays,
            presets: input.presets,
            calendar: calendar,
            timeZone: calendar.timeZone,
            now: now
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = calendar.timeZone
        let startLabel = formatter.string(from: exportRange.range.lowerBound)
        let filename = "ShiftAlarm-\(startLabel).ics"
        return try exporter.write(text: text, toTemporaryFileNamed: filename)
    }
}

struct ICSExportDateRange {
    let range: ClosedRange<Date>
    let dates: [Date]

    static func make(today: Date, months: Int, calendar: Calendar) -> ICSExportDateRange {
        let startDate = calendar.startOfDay(for: today)
        let exclusiveEndDate = calendar.date(byAdding: .month, value: months, to: startDate)!
        let lastIncludedDate = calendar.date(byAdding: .day, value: -1, to: exclusiveEndDate)!

        var dates: [Date] = []
        var cursor = startDate
        while cursor < exclusiveEndDate {
            dates.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        return ICSExportDateRange(range: startDate...lastIncludedDate, dates: dates)
    }
}
