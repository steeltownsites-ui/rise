import Foundation
import SwiftUI
import AlarmKit

/// Metadata attached to every alarm (required by AlarmKit).
struct RiseMetadata: AlarmMetadata {
    var alarmID: String
}

@MainActor
final class AlarmStore: ObservableObject {
    static let shared = AlarmStore()

    @Published var alarms: [WakeAlarm] = [] { didSet { save() } }
    @Published var history: [WakeRecord] = [] { didSet { save() } }
    @Published var sleepStart: Date? { didSet { defaults.set(sleepStart, forKey: "rise.sleepStart") } }
    @Published var defaultSound: String = "siren.caf" { didSet { defaults.set(defaultSound, forKey: "rise.defaultSound") } }
    @Published var active: ActiveMission?

    private let defaults = UserDefaults.standard
    private let manager = AlarmManager.shared

    nonisolated static let pendingKey = "rise.pendingAlarmID"
    nonisolated static let nagIDsKey = "rise.nagIDs"
    /// How long after you tap the alarm before it rings again if the mission isn't done.
    nonisolated static let nagDelay: TimeInterval = 180

    init() {
        if let d = defaults.data(forKey: "rise.alarms.v2"),
           let a = try? JSONDecoder().decode([WakeAlarm].self, from: d) { alarms = a }
        if let d = defaults.data(forKey: "rise.history.v2"),
           let h = try? JSONDecoder().decode([WakeRecord].self, from: d) { history = h }
        sleepStart = defaults.object(forKey: "rise.sleepStart") as? Date
        defaultSound = defaults.string(forKey: "rise.defaultSound") ?? "siren.caf"
        reloadPending()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(alarms), forKey: "rise.alarms.v2")
        defaults.set(try? JSONEncoder().encode(history), forKey: "rise.history.v2")
    }

    /// Called when the app comes to the front: if an alarm was just tapped, show its mission.
    func reloadPending() {
        guard active == nil, let idString = defaults.string(forKey: Self.pendingKey) else { return }
        let alarm = alarms.first { $0.id.uuidString == idString } ?? WakeAlarm(label: "Alarm")
        active = ActiveMission(alarm: alarm, test: false)
    }

    // MARK: Authorization

    func requestAuthorization() async {
        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }
    }

    // MARK: CRUD

    func upsert(_ alarm: WakeAlarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) { alarms[i] = alarm }
        else { alarms.append(alarm) }
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        Task { await sync(alarm) }
    }

    func delete(_ alarm: WakeAlarm) {
        alarms.removeAll { $0.id == alarm.id }
        try? manager.cancel(id: alarm.id)
    }

    func toggle(_ alarm: WakeAlarm) {
        var a = alarm
        a.enabled.toggle()
        upsert(a)
    }

    func resyncAll() async {
        for a in alarms { await sync(a) }
    }

    /// Cancel and (re)schedule one alarm with AlarmKit.
    func sync(_ alarm: WakeAlarm) async {
        try? manager.cancel(id: alarm.id)
        guard alarm.enabled else { return }
        await requestAuthorization()

        let all: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let weekdays = alarm.weekdays.sorted().map { all[$0 - 1] }
        let schedule = Alarm.Schedule.relative(.init(
            time: .init(hour: alarm.hour, minute: alarm.minute),
            repeats: weekdays.isEmpty ? .never : .weekly(weekdays)
        ))
        do {
            _ = try await manager.schedule(
                id: alarm.id,
                configuration: Self.configuration(schedule: schedule,
                                                  title: LocalizedStringResource(stringLiteral: alarm.label.isEmpty ? "Rise" : alarm.label),
                                                  button: Self.buttonText(alarm),
                                                  sound: alarm.sound,
                                                  alarmID: alarm.id.uuidString)
            )
        } catch {
            print("Schedule failed: \(error)")
        }
    }

    nonisolated static func buttonText(_ a: WakeAlarm) -> String {
        a.mission.hasAmount && a.mission != .math ? "Do \(a.amount) \(a.mission.unit)" : "Start \(a.mission.name)"
    }

    nonisolated static func configuration(schedule: Alarm.Schedule,
                                          title: LocalizedStringResource,
                                          button: String,
                                          sound: String?,
                                          alarmID: String) -> AlarmManager.AlarmConfiguration<RiseMetadata> {
        let alert = AlarmPresentation.Alert(
            title: title,
            stopButton: AlarmButton(text: LocalizedStringResource(stringLiteral: button),
                                    textColor: .white,
                                    systemImageName: "sun.horizon.fill")
        )
        let attributes = AlarmAttributes<RiseMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: RiseMetadata(alarmID: alarmID),
            tintColor: Color.riseGold
        )
        return .alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StartMissionIntent(alarmID: alarmID, sound: sound, button: button),
            secondaryIntent: nil,
            sound: sound.map { .named($0) } ?? .default
        )
    }

    // MARK: Missions

    func startTest(_ alarm: WakeAlarm) { active = ActiveMission(alarm: alarm, test: true) }

    func finish(_ m: ActiveMission, amount: Int, seconds: Int, skipped: Bool) {
        defer { active = nil }
        guard !m.test else { return }
        // Cancel every pending back-up alarm
        for s in defaults.stringArray(forKey: Self.nagIDsKey) ?? [] {
            if let u = UUID(uuidString: s) { try? manager.cancel(id: u) }
        }
        defaults.removeObject(forKey: Self.nagIDsKey)
        defaults.removeObject(forKey: Self.pendingKey)

        var sleep: Double? = nil
        if let s = sleepStart {
            let h = Date.now.timeIntervalSince(s) / 3600
            if h > 2 && h < 16 { sleep = h }
        }
        sleepStart = nil
        history.insert(WakeRecord(date: .now, label: m.alarm.label, mission: m.alarm.mission,
                                  amount: skipped ? 0 : amount, seconds: seconds, skipped: skipped, sleepHours: sleep), at: 0)
        if history.count > 500 { history.removeLast(history.count - 500) }
        // One-off alarms switch themselves off once done
        if let i = alarms.firstIndex(where: { $0.id == m.alarm.id }), alarms[i].weekdays.isEmpty {
            alarms[i].enabled = false
        }
    }

    // MARK: Stats

    var done: [WakeRecord] { history.filter { !$0.skipped } }

    private func days() -> Set<Date> { Set(done.map { Calendar.current.startOfDay(for: $0.date) }) }

    var streak: Int {
        let cal = Calendar.current
        let set = days()
        var day = cal.startOfDay(for: .now)
        if !set.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while set.contains(day) { n += 1; day = cal.date(byAdding: .day, value: -1, to: day)! }
        return n
    }

    var bestStreak: Int {
        let cal = Calendar.current
        var best = 0, run = 0
        var prev: Date?
        for d in days().sorted() {
            if let p = prev, cal.dateComponents([.day], from: p, to: d).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run); prev = d
        }
        return best
    }

    var todaysRecord: WakeRecord? { done.first { Calendar.current.isDateInToday($0.date) } }

    var nextAlarm: (alarm: WakeAlarm, date: Date)? {
        alarms.filter(\.enabled).compactMap { a in a.nextFire().map { (a, $0) } }.min { $0.1 < $1.1 }
    }
}
