import AppIntents
import AlarmKit
import Foundation

/// Runs when you tap the alarm's button. It stops the ringing, opens Rise on the
/// mission, and arms a back-up alarm a few minutes later. The back-up is only
/// cancelled when the mission is done, so going back to sleep doesn't work.
struct StartMissionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start wake-up mission"
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    @Parameter(title: "Alarm") var alarmID: String
    @Parameter(title: "Sound") var sound: String?
    @Parameter(title: "Button") var button: String

    init() { self.alarmID = ""; self.button = "Start" }
    init(alarmID: String, sound: String?, button: String) {
        self.alarmID = alarmID
        self.sound = sound
        self.button = button
    }

    func perform() async throws -> some IntentResult {
        let d = UserDefaults.standard
        d.set(alarmID, forKey: AlarmStore.pendingKey)

        let nagID = UUID()
        let config = AlarmStore.configuration(
            schedule: .fixed(Date().addingTimeInterval(AlarmStore.nagDelay)),
            title: "Still in bed? Finish your mission",
            button: button,
            sound: sound,
            alarmID: alarmID
        )
        _ = try? await AlarmManager.shared.schedule(id: nagID, configuration: config)
        var ids = d.stringArray(forKey: AlarmStore.nagIDsKey) ?? []
        ids.append(nagID.uuidString)
        d.set(ids, forKey: AlarmStore.nagIDsKey)

        await MainActor.run { AlarmStore.shared.reloadPending() }
        return .result()
    }
}
