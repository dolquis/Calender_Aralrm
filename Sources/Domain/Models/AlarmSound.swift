import Foundation

public struct AlarmSound: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayNameKey: String

    public init(id: String, displayNameKey: String) {
        self.id = id
        self.displayNameKey = displayNameKey
    }

    public static let systemDefault = AlarmSound(
        id: "system.default", displayNameKey: "sound.system_default")
    public static let chime = AlarmSound(id: "system.chime", displayNameKey: "sound.chime")
    public static let radar = AlarmSound(id: "system.radar", displayNameKey: "sound.radar")
    public static let bell = AlarmSound(id: "system.bell", displayNameKey: "sound.bell")

    public static let allBuiltIn: [AlarmSound] = [
        .systemDefault, .chime, .radar, .bell,
    ]

    public static func find(id: String) -> AlarmSound {
        allBuiltIn.first { $0.id == id } ?? .systemDefault
    }
}
