import Foundation
#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
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
        let title = LocalizedStringResource(stringLiteral: label)
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: title,
                secondaryButton: .openAppButton,
                secondaryButtonBehavior: .custom
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: .stopButton,
                secondaryButton: .openAppButton,
                secondaryButtonBehavior: .custom
            )
        }
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
        return AlarmManager.AlarmConfiguration.alarm(
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
