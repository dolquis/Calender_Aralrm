import Foundation
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Builds an AlarmKit `AlarmConfiguration` from app-level inputs. Kept as a single funnel so the
/// AlarmKit API surface only needs to be adjusted in one place once the iOS 26 SDK is stable.
public enum AlarmConfigurationBuilder {
    #if canImport(AlarmKit)
    public static func build(
        fireDate: Date,
        label: String,
        soundID: String
    ) -> AlarmManager.AlarmConfiguration<ShiftAlarmAttributes> {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: label),
            stopButton: .stopButton,
            secondaryButton: .openAppButton,
            secondaryButtonBehavior: .custom
        )
        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes<ShiftAlarmAttributes>(
            presentation: presentation,
            tintColor: .accentColor
        )
        let schedule = Alarm.Schedule.fixed(fireDate)
        let sound: AlertConfiguration.AlertSound
        if soundID == AlarmSound.systemDefault.id {
            sound = .default
        } else {
            sound = .named(soundID)
        }
        return AlarmManager.AlarmConfiguration(
            schedule: schedule,
            attributes: attributes,
            sound: sound
        )
    }
    #endif
}

#if canImport(AlarmKit)
private extension AlarmButton {
    static var stopButton: AlarmButton {
        AlarmButton(text: "alarm.stop", textColor: .white, systemImageName: "stop.circle.fill")
    }

    static var openAppButton: AlarmButton {
        AlarmButton(text: "alarm.open", textColor: .white, systemImageName: "app.fill")
    }
}
#endif
