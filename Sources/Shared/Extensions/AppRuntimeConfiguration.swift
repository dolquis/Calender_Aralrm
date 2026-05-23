import Foundation

public enum AppRuntimeConfiguration {
    public static let defaultAppGroupID = "group.com.example.shiftalarm"
    public static let defaultBGRefreshTaskIdentifier = "com.example.shiftalarm.refreshAlarms"

    private static let appGroupInfoKey = "ShiftAlarmAppGroupIdentifier"
    private static let bgRefreshTaskInfoKey = "ShiftAlarmBGRefreshTaskIdentifier"

    public static var appGroupID: String {
        value(forInfoKey: appGroupInfoKey, fallback: defaultAppGroupID)
    }

    public static var bgRefreshTaskIdentifier: String {
        value(forInfoKey: bgRefreshTaskInfoKey, fallback: defaultBGRefreshTaskIdentifier)
    }

    static func value(forInfoKey key: String, fallback: String, bundle: Bundle = .main) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
            !value.isEmpty,
            !value.hasPrefix("$(")
        else {
            return fallback
        }
        return value
    }
}
