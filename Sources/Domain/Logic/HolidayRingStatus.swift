import Foundation

/// Whether a holiday day rings or is silenced, for the calendar 🔔/🔕 indicator.
///
/// P2-ζ §7 wants this to reflect the effective holiday policy rather than a raw preset time.
/// Until the look-ahead auto-materialize step ships (PR-4 / DEV-528), the only days whose
/// policy the scheduler actually honors are those with a materialized `HolidayOverride` row
/// that also wins day resolution — a manual assignment overrides a holiday, and a row-less
/// known holiday falls through to rotation and really does ring. So the indicator is derived
/// from the *actual* `DayResolver` outcome for governing-holiday days only, and suppressed
/// otherwise, so the glyph and its VoiceOver label never contradict the scheduled alarm.
public enum HolidayRingStatus: Sendable, Equatable {
    case ring
    case silence

    /// The indicator to show for a day, or `nil` to show none.
    /// - Parameters:
    ///   - resolved: the resolved day from `DayResolver` (already encodes the manual > holiday >
    ///     rotation precedence).
    ///   - hasHolidayRow: whether a materialized `HolidayOverride` row exists for the day.
    ///   - hasManualAssignment: whether a manual assignment exists (which overrides holidays).
    ///
    /// Returns `nil` unless a materialized holiday row governs the day (no manual override).
    /// Row-less display-only holidays get no indicator yet — their label still shows via the
    /// calendar overlay (§6), but the bell waits until auto-materialize makes policy and
    /// scheduling agree.
    public static func forResolvedDay(
        _ resolved: ResolvedDay,
        hasHolidayRow: Bool,
        hasManualAssignment: Bool
    ) -> HolidayRingStatus? {
        guard hasHolidayRow, !hasManualAssignment else { return nil }
        return resolved.fireTime != nil ? .ring : .silence
    }
}
