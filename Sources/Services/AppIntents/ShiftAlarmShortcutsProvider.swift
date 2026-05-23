import AppIntents

/// Registers the app's Shortcuts phrases with Siri so they are discoverable without
/// the user having to open Shortcuts.app first.
public struct ShiftAlarmShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetSleepWindowIntent(),
            phrases: [
                "\(.applicationName) の次の睡眠ウィンドウを取得",
                "Get next sleep window from \(.applicationName)",
            ],
            shortTitle: "次の睡眠ウィンドウ",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: GetNextWakeTimeIntent(),
            phrases: [
                "\(.applicationName) の次の起床時刻を教えて",
                "Get next wake time from \(.applicationName)",
            ],
            shortTitle: "次の起床時刻",
            systemImageName: "alarm.fill"
        )
        AppShortcut(
            intent: GetNextBedtimeIntent(),
            phrases: [
                "\(.applicationName) の就寝時刻を教えて",
                "Get next bedtime from \(.applicationName)",
            ],
            shortTitle: "次の就寝時刻",
            systemImageName: "bed.double.fill"
        )
    }
}
