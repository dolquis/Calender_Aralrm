import Foundation
import SwiftData
import Testing

@testable import ShiftAlarm

@MainActor
struct ShareExporterTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func testSnapshotRoundTripsThroughCodecAndImporter() throws {
        let source = SharedPersistence.makeContainer(inMemory: true)
        let presetID = UUID()
        let replacementPresetID = UUID()
        let anchor = try #require(CalendarDay(year: 2026, month: 5, day: 1).date(in: calendar))
        let overrideDay = try #require(CalendarDay(year: 2026, month: 5, day: 2).date(in: calendar))
        let sourceContext = ModelContext(source)
        let dayPreset = ShiftPreset(
            id: presetID,
            name: "Day",
            colorHex: "#1E88E5",
            defaultAlarmHour: 7,
            defaultAlarmMinute: 0,
            note: "primary",
            crossVacationPolicy: .continue
        )
        let replacementPreset = ShiftPreset(
            id: replacementPresetID,
            name: "Night",
            colorHex: "#8E24AA",
            defaultAlarmHour: 22,
            defaultAlarmMinute: 15
        )
        sourceContext.insert(dayPreset)
        sourceContext.insert(replacementPreset)
        sourceContext.insert(
            RotationPattern(
                name: "Three day",
                anchorDate: anchor,
                cycleLength: 3,
                slots: [presetID, nil, replacementPresetID],
                startDate: anchor,
                endDate: overrideDay,
                priority: 2,
                crossVacationPolicy: .resetToDay,
                dayStartSlotIndex: 1
            ))
        sourceContext.insert(
            DayAssignment(
                date: anchor,
                preset: dayPreset,
                overrideAlarmHour: 8,
                overrideAlarmMinute: 30,
                skipAlarm: false,
                note: "early"
            ))
        sourceContext.insert(
            HolidayOverride(
                date: overrideDay,
                kind: .paidLeave,
                label: "Leave",
                skipAlarm: false,
                replacementPreset: replacementPreset
            ))
        try sourceContext.save()

        let exported = try ShareExporter.snapshot(from: source, calendar: calendar)
        let decoded = try ShiftBundleCodec.decode(try ShiftBundleCodec.encode(exported))
        let destination = SharedPersistence.makeContainer(inMemory: true)
        try ShareImporter.apply(bundle: decoded, container: destination, calendar: calendar)

        let context = ModelContext(destination)
        let presets = try context.fetch(FetchDescriptor<ShiftPreset>())
        let patterns = try context.fetch(FetchDescriptor<RotationPattern>())
        let assignments = try context.fetch(FetchDescriptor<DayAssignment>())
        let overrides = try context.fetch(FetchDescriptor<HolidayOverride>())
        let pattern = try #require(patterns.first)
        let assignment = try #require(assignments.first)
        let override = try #require(overrides.first)

        #expect(presets.count == 2)
        #expect(patterns.count == 1)
        #expect(assignments.count == 1)
        #expect(overrides.count == 1)
        #expect(pattern.slots == [presetID, nil, replacementPresetID])
        #expect(pattern.priority == 2)
        #expect(pattern.crossVacationPolicy == .resetToDay)
        #expect(pattern.dayStartSlotIndex == 1)
        #expect(assignment.preset?.id == presetID)
        #expect(assignment.overrideAlarmHour == 8)
        #expect(assignment.overrideAlarmMinute == 30)
        #expect(!assignment.skipAlarm)
        #expect(assignment.note == "early")
        #expect(override.kind == .paidLeave)
        #expect(override.label == "Leave")
        #expect(!override.skipAlarm)
        #expect(override.replacementPreset?.id == replacementPresetID)
    }

    @Test
    func testWriteTemporaryFileProducesDecodableShiftAlarmBundle() throws {
        let bundle = ShiftBundle(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            presets: [
                ShiftBundle.PresetDTO(
                    id: UUID(),
                    name: "Day",
                    colorHex: "#1E88E5",
                    defaultAlarmHour: 7,
                    defaultAlarmMinute: 0,
                    soundID: AlarmSound.systemDefault.id,
                    note: "exported"
                )
            ]
        )

        let url = try ShareExporter.writeTemporaryFile(bundle: bundle)
        defer { try? FileManager.default.removeItem(at: url) }
        let decoded = try ShiftBundleCodec.decode(Data(contentsOf: url))

        #expect(url.pathExtension == "shiftalarm")
        #expect(decoded == bundle)
    }
}
