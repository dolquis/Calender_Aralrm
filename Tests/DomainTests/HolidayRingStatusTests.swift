import Foundation
import Testing

@testable import ShiftAlarm

/// P2-ζ (DEV-201) calendar 🔔/🔕 derivation. The indicator must match the real `DayResolver`
/// outcome and never contradict the scheduled alarm (review feedback on PR #63).
struct HolidayRingStatusTests {
    // No materialized holiday row → no indicator (row-less bundled holidays wait for
    // auto-materialize; their label still shows via the overlay).
    @Test
    func noRowShowsNoIndicator() {
        #expect(
            HolidayRingStatus.forResolvedDay(
                .rotation(presetID: UUID(), alarmTime: DateComponents(hour: 7)),
                hasHolidayRow: false, hasManualAssignment: false) == nil)
    }

    // A manual assignment overrides holidays in `DayResolver`, so the holiday indicator is
    // suppressed even when a row exists — otherwise VoiceOver could wrongly announce a ringing day.
    @Test
    func manualAssignmentSuppressesIndicator() {
        #expect(
            HolidayRingStatus.forResolvedDay(
                .manual(
                    presetID: UUID(), alarmTime: DateComponents(hour: 9), skip: false, note: ""),
                hasHolidayRow: true, hasManualAssignment: true) == nil)
    }

    // A governing silenced holiday (no fire time) → 🔕.
    @Test
    func governingSilencedHolidayIsSilent() {
        #expect(
            HolidayRingStatus.forResolvedDay(
                .holiday(label: "海の日", replacementPresetID: nil, alarmTime: nil, skip: true),
                hasHolidayRow: true, hasManualAssignment: false) == .silence)
    }

    // A governing holiday that fires — via replacement preset or a rotation fall-through — → 🔔.
    @Test
    func governingRingingHolidayRings() {
        #expect(
            HolidayRingStatus.forResolvedDay(
                .holiday(
                    label: "海の日", replacementPresetID: UUID(),
                    alarmTime: DateComponents(hour: 10), skip: false),
                hasHolidayRow: true, hasManualAssignment: false) == .ring)
        // ring behavior with no replacement falls through to rotation, which still fires.
        #expect(
            HolidayRingStatus.forResolvedDay(
                .rotation(presetID: UUID(), alarmTime: DateComponents(hour: 7)),
                hasHolidayRow: true, hasManualAssignment: false) == .ring)
    }
}
