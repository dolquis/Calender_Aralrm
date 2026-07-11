import Foundation
import SwiftData

/// Lazy, idempotent backfill for the P2-ζ holiday-alarm columns added in SchemaV6.
///
/// Runs once when the shared container opens (see `SharedPersistence.makeContainer`). It
/// only touches rows whose new columns are still nil, so repeated runs are no-ops.
///
/// Mapping (matches `docs/p2-holiday-alarm-control.md` §4.4):
/// - `HolidayOverride.alarmBehaviorRaw == nil` → `skipAlarm ? .inherit : .ring`.
///   `true → inherit` lets the app-wide toggle govern previously-silenced holidays (the
///   primary use case). This is deliberately different from the `.shiftalarm` import path,
///   which maps `true → silence` to preserve another device's explicit intent.
/// - `AppSettings.holidayAlarmDefaultRaw == nil` → `.silence`, preserving the pre-P2-ζ
///   behavior where holidays were silent by default.
public enum HolidayBehaviorBackfill {
    public static func run(container: ModelContainer) {
        let context = ModelContext(container)
        run(in: context)
    }

    /// Backfills within an existing context. Saves only when it changed something.
    @discardableResult
    public static func run(in context: ModelContext) -> Int {
        var changed = 0

        let overrides = (try? context.fetch(FetchDescriptor<HolidayOverride>())) ?? []
        for override in overrides where override.alarmBehaviorRaw == nil {
            override.alarmBehaviorRaw =
                (override.skipAlarm ? HolidayAlarmBehavior.inherit : .ring).rawValue
            changed += 1
        }

        let settingsList = (try? context.fetch(FetchDescriptor<AppSettings>())) ?? []
        for settings in settingsList where settings.holidayAlarmDefaultRaw == nil {
            settings.holidayAlarmDefaultRaw = HolidayAlarmBehavior.silence.rawValue
            changed += 1
        }

        if changed > 0 {
            try? context.save()
        }
        return changed
    }
}
