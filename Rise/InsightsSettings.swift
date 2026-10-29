import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var store: AlarmStore

    private struct DayPoint: Identifiable { let id = UUID(); let day: Date; let minutes: Double }

    private var points: [DayPoint] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: .now))!
        var best: [Date: Double] = [:]
        for r in store.done where r.date >= start {
            let d = cal.startOfDay(for: r.date)
            let m = Double(cal.component(.hour, from: r.date) * 60 + cal.component(.minute, from: r.date))
            best[d] = min(best[d] ?? .infinity, m)
        }
        return best.map { DayPoint(day: $0.key, minutes: $0.value) }.sorted { $0.day < $1.day }
    }

    private func clock(_ m: Double) -> String {
        let d = Calendar.current.date(from: DateComponents(hour: Int(m) / 60, minute: Int(m) % 60)) ?? .now
        return d.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let pts = points
                    let sleeps = store.done.compactMap(\.sleepHours).prefix(14)
                    let reps = store.done.filter { $0.mission.isPose }.reduce(0) { $0 + $1.amount }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        tile("\(store.streak)", "day streak")
                        tile("\(store.bestStreak)", "best streak")
                        tile(pts.isEmpty ? "–" : clock(pts.map(\.minutes).reduce(0, +) / Double(pts.count)), "average wake-up, 14 days")
                        tile(sleeps.isEmpty ? "–" : String(format: "%.1f h", sleeps.reduce(0, +) / Double(sleeps.count)), "average sleep")
                        tile("\(store.done.count)", "missions done")
                        tile("\(reps)", "push-ups and squats")
                    }

                    card {
                        Text("Wake-up times").font(.headline)
                        Text("Last 14 days").font(.caption).foregroundStyle(.secondary)
                        if pts.isEmpty {
                            Text("Your mornings appear here after your first mission.").foregroundStyle(.secondary).padding(.vertical, 20)
                        } else {
                            Chart(pts) { p in
                                LineMark(x: .value("Day", p.day, unit: .day), y: .value("Time", p.minutes))
                                    .foregroundStyle(Color.riseGold)
                                PointMark(x: .value("Day", p.day, unit: .day), y: .value("Time", p.minutes))
                                    .foregroundStyle(Color.riseGold)
                            }
                            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                            .chartYAxis { AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel { if let m = v.as(Double.self) { Text(clock(m)) } }
                            } }
                            .frame(height: 180)
                        }
                    }

                    card {
                        Text("Missions").font(.headline)
                        let counts = Dictionary(grouping: store.done, by: \.mission).mapValues(\.count)
                        let maxC = max(1, counts.values.max() ?? 1)
                        ForEach(Mission.allCases) { m in
                            HStack {
                                Text(m.name).frame(width: 100, alignment: .leading).font(.subheadline)
                                GeometryReader { g in
                                    Capsule().fill(Color.gray.opacity(0.15))
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(Color.riseGold).frame(width: g.size.width * CGFloat(counts[m] ?? 0) / CGFloat(maxC))
                                        }
                                }
                                .frame(height: 10)
                                Text("\(counts[m] ?? 0)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit().frame(width: 28, alignment: .trailing)
                            }
                        }
                    }

                    card {
                        Text("Recent mornings").font(.headline)
                        if store.history.isEmpty { Text("No mornings yet.").foregroundStyle(.secondary) }
                        ForEach(store.history.prefix(10)) { r in
                            HStack {
                                Text(r.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                                Spacer()
                                Text(summary(r)).foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            Divider()
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.riseBG.ignoresSafeArea())
            .navigationTitle("Insights")
        }
    }

    private func tile(_ v: String, _ k: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 28, weight: .black)).monospacedDigit()
            Text(k).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.riseCard))
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8, content: c)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.riseCard))
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AlarmStore

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        SoundPickerView(selection: Binding(get: { store.defaultSound }, set: { store.defaultSound = $0 ?? "siren.caf" }))
                    } label: {
                        LabeledContent("Sound for new alarms", value: SoundLibrary.displayName(store.defaultSound))
                    }
                } footer: {
                    Text("Each alarm can have its own sound. Edit an alarm to change it.")
                }

                Section("How Rise works") {
                    Text("Alarms ring like the Clock app, even when the phone is locked or on silent. Tap the button on the alarm to open your mission. If you don't finish it, the alarm rings again 3 minutes later.")
                    Text("Push-ups and squats: stand the phone side-on to you so your whole body is in shot. The camera counts each full rep out loud.")
                }

                Section("Keeping Rise installed") {
                    Text("Installed with a free Apple ID, Rise needs refreshing every 7 days. Your alarms and history are kept when you refresh.")
                }

                Section {
                    Button("Re-sync all alarms") { Task { await store.resyncAll() } }
                } footer: {
                    Text("Use this if an alarm didn't ring after reinstalling Rise.")
                }
            }
            .navigationTitle("Settings")
            .tint(.riseGold)
        }
    }
}
