import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AlarmStore
    @State private var editing: WakeAlarm?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    TimelineView(.periodic(from: .now, by: 30)) { _ in countdown }
                    sectionTitle("Mission Alarms")
                    if store.alarms.isEmpty {
                        emptyCard
                    } else {
                        ForEach(store.alarms) { alarm in
                            AlarmCard(alarm: alarm,
                                      onToggle: { store.toggle(alarm) },
                                      onEdit: { editing = alarm })
                        }
                    }
                    sectionTitle("Today's wake-up")
                    todayCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .background(Color.riseBG.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                Button { editing = WakeAlarm(sound: store.defaultSound) } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 62, height: 62)
                        .background(Circle().fill(Color.riseCard))
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                }
                .accessibilityLabel("New alarm")
                .padding(20)
            }
            .sheet(item: $editing) { alarm in
                EditAlarmView(alarm: alarm, isNew: !store.alarms.contains { $0.id == alarm.id })
                    .environmentObject(store)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Rise").font(.system(size: 34, weight: .black))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").foregroundStyle(Color.riseGold)
                Text("\(store.streak)").font(.headline).monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.riseCard))
        }
        .padding(.top, 8)
    }

    private var countdown: some View {
        VStack(spacing: 6) {
            if let next = store.nextAlarm {
                let mins = max(0, Int(next.date.timeIntervalSinceNow / 60))
                Text("\(next.alarm.label.isEmpty ? "Alarm" : next.alarm.label) rings in").font(.subheadline.weight(.medium))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if mins >= 1440 {
                        big("\(mins / 1440)"); small("d"); big("\(mins % 1440 / 60)"); small("hr")
                    } else if mins >= 60 {
                        big("\(mins / 60)"); small("hr"); big("\(mins % 60)"); small("min")
                    } else {
                        big("\(mins)"); small("min")
                    }
                }
            } else {
                Text("No alarms on").font(.subheadline.weight(.medium))
                big("–")
            }
            Button {
                store.sleepStart = store.sleepStart == nil ? .now : nil
            } label: {
                Label(store.sleepStart.map { "Sleeping since \($0.formatted(date: .omitted, time: .shortened)) · Cancel" } ?? "Track sleep",
                      systemImage: "moon.zzz.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color.riseCard.opacity(0.85)))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color(red: 0.70, green: 0.76, blue: 0.85),
                                              Color(red: 0.92, green: 0.87, blue: 0.78),
                                              Color(red: 0.84, green: 0.67, blue: 0.34)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.06))
    }

    private func big(_ s: String) -> some View { Text(s).font(.system(size: 52, weight: .black)).monospacedDigit() }
    private func small(_ s: String) -> some View { Text(s).font(.title3.weight(.semibold)) }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 6).padding(.leading, 4)
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "alarm").font(.largeTitle).foregroundStyle(Color.riseGold)
            Text("No alarms yet").font(.headline)
            Text("Tap + to add one. You switch it off by finishing a mission.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(28).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.riseCard))
    }

    private var todayCard: some View {
        HStack(spacing: 12) {
            if let r = store.todaysRecord {
                Image(systemName: r.mission.symbol).foregroundStyle(Color.riseGold)
                    .frame(width: 44, height: 44).background(Circle().fill(Color.riseSoft))
                VStack(alignment: .leading) {
                    Text(r.date.formatted(date: .omitted, time: .shortened)).font(.title3.bold())
                    Text(summary(r)).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "moon.fill").foregroundStyle(Color.riseGold)
                    .frame(width: 44, height: 44).background(Circle().fill(Color.riseSoft))
                Text("Not up yet today").foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.riseCard))
    }
}

func summary(_ r: WakeRecord) -> String {
    if r.skipped { return "Skipped" }
    let what = r.mission.hasAmount ? "\(r.mission.name) · \(r.amount) \(r.mission.unit)" : r.mission.name
    return "\(what) · \(r.seconds)s"
}

struct AlarmCard: View {
    let alarm: WakeAlarm
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alarm.repeatString).font(.footnote).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(alarm.timeString).font(.system(size: 34, weight: .heavy)).monospacedDigit()
                        Image(systemName: alarm.mission.symbol).foregroundStyle(.secondary)
                    }
                    Text(alarm.label.isEmpty ? alarm.mission.name : alarm.label)
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .opacity(alarm.enabled ? 1 : 0.45)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle("", isOn: Binding(get: { alarm.enabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .tint(.riseGold)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.riseCard))
    }
}
