import Foundation

/// Whether a holiday's alarm rings, stays silent, or follows the app-wide default.
///
/// - `inherit` is only valid on an individual `HolidayOverride` row; it defers to
///   `AppSettings.effectiveHolidayAlarmDefault`. The app-wide default itself is always
///   a concrete `ring`/`silence` (see `AppSettings.holidayAlarmDefault`), because
///   `inherit` must resolve to a concrete value.
/// - `ring`: fire the alarm (its `replacementPreset` time if present, otherwise fall
///   through to the normal rotation resolution).
/// - `silence`: do not fire an alarm on this holiday.
public enum HolidayAlarmBehavior: Int, Codable, Sendable, CaseIterable {
    case inherit = 0
    case ring = 1
    case silence = 2

    /// Resolve `inherit` against a concrete app-wide default. `ring`/`silence` pass through.
    public func resolved(default fallback: HolidayAlarmBehavior) -> HolidayAlarmBehavior {
        self == .inherit ? fallback : self
    }
}
