import SwiftUI
import SwiftData

public struct ICSExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDependencies.self) private var dependencies
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
        do {
            fileURL = try buildICSFile(container: dependencies.modelContainer, months: monthCount)
        } catch {
            errorMessage = error.localizedDescription
        }
        preparing = false
    }

    private func buildICSFile(container: ModelContainer, months: Int) throws -> URL {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let endDate = calendar.date(byAdding: .month, value: months, to: today)!

        let input = DayResolverInputBuilder.make(context: ModelContext(container), calendar: calendar)
        var resolvedDays: [ResolvedDay] = []
        var cursor = today
        while cursor <= endDate {
            resolvedDays.append(DayResolver.resolve(date: cursor, input: input))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        let exporter = ICSExporter()
        let text = exporter.export(
            range: today...endDate,
            resolvedDays: resolvedDays,
            presets: input.presets,
            calendar: calendar,
            timeZone: calendar.timeZone,
            now: Date.now
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = calendar.timeZone
        let startLabel = formatter.string(from: today)
        let filename = "ShiftAlarm-\(startLabel).ics"
        return try exporter.write(text: text, toTemporaryFileNamed: filename)
    }
}
