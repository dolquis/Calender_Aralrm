import Foundation
import SwiftData

@MainActor
public enum PresetSeed {
    public static func seedDefaultsIfNeeded(modelContext: ModelContext) {
        let existing: [ShiftPreset] =
            (try? modelContext.fetch(FetchDescriptor<ShiftPreset>())) ?? []
        guard existing.isEmpty else { return }
        let day = ShiftPreset(
            name: String(localized: "seed.day_shift"),
            colorHex: "#43A047",
            defaultAlarmHour: 6,
            defaultAlarmMinute: 30
        )
        let night = ShiftPreset(
            name: String(localized: "seed.night_shift"),
            colorHex: "#1E88E5",
            defaultAlarmHour: 20,
            defaultAlarmMinute: 0
        )
        modelContext.insert(day)
        modelContext.insert(night)
        try? modelContext.save()
    }
}
