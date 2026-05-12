import XCTest
@testable import ShiftAlarm

final class ShiftBundleCodecTests: XCTestCase {
    func testRoundTrip() throws {
        let presetID = UUID()
        let bundle = ShiftBundle(
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            presets: [
                ShiftBundle.PresetDTO(
                    id: presetID,
                    name: "夜勤",
                    colorHex: "#1E88E5",
                    defaultAlarmHour: 20,
                    defaultAlarmMinute: 0,
                    soundID: "system.default",
                    note: ""
                )
            ],
            patterns: [
                ShiftBundle.RotationDTO(
                    id: UUID(),
                    name: "4勤2休",
                    anchorDate: Date(timeIntervalSince1970: 1_700_000_000),
                    cycleLength: 6,
                    slots: [presetID, presetID, presetID, presetID, nil, nil],
                    startDate: nil,
                    endDate: nil,
                    priority: 0,
                    isActive: true
                )
            ],
            assignments: [
                ShiftBundle.AssignmentDTO(
                    date: Date(timeIntervalSince1970: 1_700_000_000),
                    presetID: presetID,
                    overrideAlarmHour: 21,
                    overrideAlarmMinute: 30,
                    skipAlarm: false,
                    note: ""
                )
            ],
            overrides: [
                ShiftBundle.OverrideDTO(
                    date: Date(timeIntervalSince1970: 1_700_000_000),
                    kind: .publicHoliday,
                    label: "元日",
                    skipAlarm: true,
                    replacementPresetID: nil
                )
            ]
        )
        let data = try ShiftBundleCodec.encode(bundle)
        let decoded = try ShiftBundleCodec.decode(data)
        XCTAssertEqual(decoded, bundle)
    }

    func testInvalidPayloadThrows() {
        XCTAssertThrowsError(try ShiftBundleCodec.decode(Data("{not json}".utf8)))
    }
}
