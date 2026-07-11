import Testing

@testable import ShiftAlarm

/// P2-ζ (DEV-201) calendar 🔔/🔕 effective-policy resolution. Test IDs HOL-V1/V2 (logic).
struct HolidayRingStatusTests {
    // A materialized row's concrete behavior wins over the global default.
    @Test
    func rowSilenceIsSilentEvenWhenGlobalRings() {
        #expect(
            HolidayRingStatus.resolve(rowBehavior: .silence, globalDefault: .ring) == .silence)
    }

    @Test
    func rowRingRingsEvenWhenGlobalSilences() {
        #expect(HolidayRingStatus.resolve(rowBehavior: .ring, globalDefault: .silence) == .ring)
    }

    // `inherit` rows follow the global default.
    @Test
    func inheritFollowsGlobalDefault() {
        #expect(
            HolidayRingStatus.resolve(rowBehavior: .inherit, globalDefault: .silence) == .silence)
        #expect(HolidayRingStatus.resolve(rowBehavior: .inherit, globalDefault: .ring) == .ring)
    }

    // HOL-V2: a display-only holiday (no row) is treated as `.inherit` and follows the global
    // default — so under a silence default it shows 🔕 regardless of any rotation fire time.
    @Test
    func displayOnlyHolidayFollowsGlobalDefault() {
        #expect(HolidayRingStatus.resolve(rowBehavior: nil, globalDefault: .silence) == .silence)
        #expect(HolidayRingStatus.resolve(rowBehavior: nil, globalDefault: .ring) == .ring)
    }
}
