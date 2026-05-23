import Foundation

public enum SleepWindowResolver {
    /// Returns sleep windows for each day in `dates` that has a wake alarm with a known preset.
    /// Days without an alarm, or whose preset has no alarm time, are omitted.
    public static func resolve(
        dates: [Date],
        input: DayResolverInput
    ) -> [SleepWindow] {
        let calendar = input.calendar
        var windows: [SleepWindow] = []

        for day in dates {
            let resolved = DayResolver.resolve(date: day, input: input)
            guard !resolved.skipsAlarm,
                let fireTime = resolved.fireTime,
                let hour = fireTime.hour,
                let minute = fireTime.minute,
                let wakeTime = day.combining(hour: hour, minute: minute, in: calendar),
                let presetID = resolved.presetID,
                let preset = input.presets[presetID]
            else { continue }

            let bedtime = wakeTime.addingTimeInterval(-preset.targetSleepDuration)
            let reminderFireDate: Date? =
                preset.bedtimeLeadMinutes > 0
                ? bedtime.addingTimeInterval(-Double(preset.bedtimeLeadMinutes) * 60)
                : nil

            windows.append(
                SleepWindow(
                    date: calendar.startOfDay(for: day),
                    wakeTime: wakeTime,
                    bedtime: bedtime,
                    reminderFireDate: reminderFireDate,
                    presetID: presetID,
                    presetName: preset.name
                ))
        }

        return windows.sorted { $0.wakeTime < $1.wakeTime }
    }
}
