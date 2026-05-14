import AppIntents
import Foundation

/// Returns the next computed sleep window (bedtime + wake time) based on the shift calendar.
/// Use this in a Shortcuts personal automation to feed "Toggle Sleep Focus" and alarm actions.
public struct GetSleepWindowIntent: AppIntent {
    public static var title: LocalizedStringResource = "次の睡眠ウィンドウを取得"
    public static var description = IntentDescription("シフトカレンダーから次の就寝時刻と起床時刻を返します。")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some ReturnsValue<SleepWindowEntity> {
        guard let window = await SleepIntentHelper.fetchNextWindow() else {
            throw IntentError.noUpcomingWindow
        }
        return .result(value: window)
    }
}

/// Returns only the next wake (alarm) time as a Date.
public struct GetNextWakeTimeIntent: AppIntent {
    public static var title: LocalizedStringResource = "次の起床時刻を取得"
    public static var description = IntentDescription("シフトカレンダーから次の起床アラーム時刻を返します。")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some ReturnsValue<Date> {
        guard let window = await SleepIntentHelper.fetchNextWindow() else {
            throw IntentError.noUpcomingWindow
        }
        return .result(value: window.wakeTime)
    }
}

/// Returns only the next computed bedtime as a Date.
public struct GetNextBedtimeIntent: AppIntent {
    public static var title: LocalizedStringResource = "次の就寝時刻を取得"
    public static var description = IntentDescription("シフトカレンダーから次の就寝推奨時刻を返します。")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some ReturnsValue<Date> {
        guard let window = await SleepIntentHelper.fetchNextWindow() else {
            throw IntentError.noUpcomingWindow
        }
        return .result(value: window.bedtime)
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case noUpcomingWindow

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noUpcomingWindow:
            return "今後のシフトアラームが見つかりません。カレンダーにシフトを設定してください。"
        }
    }
}
