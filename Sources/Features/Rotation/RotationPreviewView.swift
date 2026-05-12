import SwiftUI

public struct RotationPreviewView: View {
    let anchor: Date
    let cycleLength: Int
    let slots: [UUID?]
    let presets: [ShiftPreset]
    let startDate: Date?
    let endDate: Date?

    private let previewDays = 14

    public init(
        anchor: Date,
        cycleLength: Int,
        slots: [UUID?],
        presets: [ShiftPreset],
        startDate: Date?,
        endDate: Date?
    ) {
        self.anchor = anchor
        self.cycleLength = cycleLength
        self.slots = slots
        self.presets = presets
        self.startDate = startDate
        self.endDate = endDate
    }

    private var presetMap: [UUID: ShiftPreset] {
        presets.reduce(into: [:]) { acc, p in acc[p.id] = p }
    }

    private var snapshot: RotationPatternSnapshot {
        RotationPatternSnapshot(
            id: UUID(),
            name: "preview",
            anchorDate: anchor,
            cycleLength: cycleLength,
            slots: slots,
            startDate: startDate,
            endDate: endDate,
            priority: 0,
            isActive: true
        )
    }

    public var body: some View {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let dates = (0..<previewDays).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        VStack(alignment: .leading, spacing: 4) {
            ForEach(dates, id: \.self) { date in
                let id = RotationExpander.presetID(for: date, pattern: snapshot, calendar: calendar)
                let preset = id.flatMap { presetMap[$0] }
                HStack {
                    Text(dateString(date))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 96, alignment: .leading)
                    if let preset {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: preset.colorHex))
                            .frame(width: 12, height: 12)
                        Text(preset.name)
                    } else {
                        Text("rotation.rest_day")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("Mdee")
        return formatter.string(from: date)
    }
}
