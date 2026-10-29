import SwiftUI
import AVFoundation

struct MissionFlowView: View {
    let mission: ActiveMission
    @EnvironmentObject var store: AlarmStore
    @State private var phase: Phase = .intro
    @State private var started = Date()
    @State private var amount = 0
    @State private var skipped = false
    @State private var ringing = false
    @State private var escapeProgress: CGFloat = 0
    @State private var escapeTimer: Timer?
    private let speech = AVSpeechSynthesizer()

    enum Phase { case intro, running, done }
    private var alarm: WakeAlarm { mission.alarm }

    var body: some View {
        ZStack {
            Color.riseBG.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Text("\(alarm.label.isEmpty ? "Alarm" : alarm.label) · \(alarm.timeString)\(mission.test ? " · test" : "")")
                    Spacer()
                    if ringing {
                        Label("Ringing", systemImage: "speaker.wave.3.fill").foregroundStyle(.red)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

                switch phase {
                case .intro: intro
                case .running: running
                case .done: done
                }

                if phase != .done { escapeHatch }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear {
            started = .now
            UIApplication.shared.isIdleTimerDisabled = true
            SoundLibrary.shared.startRinging(alarm.sound)
            ringing = true
        }
        .onDisappear {
            SoundLibrary.shared.stopRinging()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: alarm.mission.symbol)
                .font(.system(size: 44))
                .foregroundStyle(Color.riseGold)
                .frame(width: 104, height: 104)
                .background(Circle().fill(Color.riseSoft))
            Text(alarm.mission.name).font(.system(size: 34, weight: .black))
            Text(task).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
            Button {
                phase = .running
                if alarm.mission.isPose || [.object, .sky, .bed].contains(alarm.mission) {
                    SoundLibrary.shared.stopRinging(); ringing = false
                }
            } label: {
                Text("I'm awake — start")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary))
                    .foregroundStyle(Color.riseBG)
            }
        }
    }

    private var task: String {
        switch alarm.mission {
        case .pushups, .squats: return "Do \(alarm.amount) \(alarm.mission.unit) to switch off your alarm. The camera counts them."
        case .math: return "Solve \(alarm.amount) \(alarm.amount == 1 ? "problem" : "problems") to switch off your alarm. It keeps ringing until you do."
        case .object: return "Find the object Rise asks for and photograph it."
        case .sky: return "Go to a window or outside and photograph the sky."
        case .bed: return "Make your bed, then photograph it."
        case .affirm: return "Type out today's affirmation exactly. It keeps ringing until you do."
        }
    }

    // MARK: Running

    @ViewBuilder private var running: some View {
        switch alarm.mission {
        case .pushups, .squats:
            PoseMissionView(mission: alarm.mission, target: alarm.amount) { n in complete(n) }
        case .math:
            MathMissionView(count: alarm.amount, level: alarm.level) { complete(alarm.amount) }
        case .object, .sky, .bed:
            PhotoMissionView(kind: alarm.mission) { complete(1) }
        case .affirm:
            AffirmationMissionView { complete(1) }
        }
    }

    private func complete(_ n: Int, skip: Bool = false) {
        guard phase != .done else { return }
        SoundLibrary.shared.stopRinging(); ringing = false
        amount = n; skipped = skip
        phase = .done
        if !skip {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            speech.speak(AVSpeechUtterance(string: "Good morning."))
        }
    }

    // MARK: Done

    private var done: some View {
        let secs = Int(Date().timeIntervalSince(started))
        return VStack(spacing: 16) {
            Spacer()
            Image(systemName: skipped ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 54)).foregroundStyle(Color.riseGold)
            Text(skipped ? "Skipped" : "Good morning.").font(.system(size: 38, weight: .black))
            Text(mission.test ? "That was a test run, so it isn't logged."
                 : skipped ? "Your streak starts again tomorrow."
                 : "\(alarm.mission.hasAmount ? "\(amount) \(alarm.mission.unit)" : alarm.mission.name) in \(secs)s. Streak: \(store.streak + (store.todaysRecord == nil ? 1 : 0)) days.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            Button {
                store.finish(mission, amount: amount, seconds: secs, skipped: skipped)
            } label: {
                Text("Start the day")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.riseGold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: Skip

    /// Injured or travelling? Hold for 15 seconds to bail out.
    private var escapeHatch: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.riseCard)
            Capsule().fill(Color.riseSoft).frame(width: max(0, escapeProgress) * 220)
            Text("Hold 15 s to skip today").font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
        .frame(width: 220, height: 34)
        .onLongPressGesture(minimumDuration: 15, pressing: { pressing in
            escapeTimer?.invalidate()
            if pressing {
                let start = Date()
                escapeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    escapeProgress = min(1, Date().timeIntervalSince(start) / 15)
                }
            } else {
                escapeProgress = 0
            }
        }, perform: {
            escapeTimer?.invalidate()
            complete(0, skip: true)
        })
    }
}
