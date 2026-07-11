import Foundation

/// Whether a holiday day effectively rings or is silenced, for the calendar 🔔/🔕 indicator.
///
/// P2-ζ §7: the indicator must come from the *effective holiday policy*, not the raw
/// `fireTime`. A display-only (un-materialized) known holiday falls through to rotation
/// resolution and would show a non-nil `fireTime`, so `fireTime` alone would wrongly render
/// "rings" for a future/out-of-window holiday under a `silence` default. Resolving the
/// behavior against the app-wide default matches what the scheduler will actually do once the
/// day is materialized.
public enum HolidayRingStatus: Sendable, Equatable {
    case ring
    case silence

    /// Resolve the effective status for a holiday day.
    /// - Parameters:
    ///   - rowBehavior: the materialized `HolidayOverride` behavior, or `nil` for a display-only
    ///     known holiday (bundled/EventKit) with no row yet — which materializes as `.inherit`.
    ///   - globalDefault: the app-wide default (`ring`/`silence`) that `.inherit` resolves to.
    public static func resolve(
        rowBehavior: HolidayAlarmBehavior?,
        globalDefault: HolidayAlarmBehavior
    ) -> HolidayRingStatus {
        let effective = (rowBehavior ?? .inherit).resolved(default: globalDefault)
        return effective == .silence ? .silence : .ring
    }
}
