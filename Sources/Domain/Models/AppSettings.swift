import Foundation
import SwiftData

@Model
public final class AppSettings {
    @Attribute(.unique) public var id: UUID
    public var defaultSoundID: String
    public var lookaheadDays: Int
    public var liveActivityLeadHours: Int
    public var preferredLanguageRaw: String?
    public var hasOnboarded: Bool

    public init(
        id: UUID = UUID(),
        defaultSoundID: String = AlarmSound.systemDefault.id,
        lookaheadDays: Int = 30,
        liveActivityLeadHours: Int = 8,
        preferredLanguageRaw: String? = nil,
        hasOnboarded: Bool = false
    ) {
        self.id = id
        self.defaultSoundID = defaultSoundID
        self.lookaheadDays = lookaheadDays
        self.liveActivityLeadHours = liveActivityLeadHours
        self.preferredLanguageRaw = preferredLanguageRaw
        self.hasOnboarded = hasOnboarded
    }
}
