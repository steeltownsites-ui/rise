import SwiftUI

struct EditAlarmView: View {
    @EnvironmentObject var store: AlarmStore
    @Environment(\.dismiss) private var dismiss
    @State var alarm: WakeAlarm
    let isNew: Bool
    @State private var confirmDelete = false

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: alarm.hour, minute: alarm.minute)) ?? .now },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                alarm.hour = c.hour ?? 7
                alarm.minute = c.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                Section("Repeat") {
                    HStack {
                        ForEach(1...7, id: \.self) { d in
                            let on = alarm.weekdays.contains(d)
                            Button {
                                if on { alarm.weekdays.remove(d) } else { alarm.weekdays.insert(d) }
                            } label: {
                                Text(Calendar.current.veryShortWeekdaySymbols[d - 1])
                                    .font(.subheadline.bold())
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(on ? Color.riseGold : Color.gray.opacity(0.12)))
                                    .foregroundStyle(on ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                Section("Mission") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        ForEach(Mission.allCases) { m in
                            Button {
                                alarm.mission = m
                                alarm.amount = m.defaultAmount
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: m.symbol)
                                        .font(.title3)
                                        .foregroundStyle(Color.riseGold)
                                        .frame(width: 42, height: 42)
                                        .background(Circle().fill(Color.riseSoft))
                                    Text(m.name).font(.caption.bold()).foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 16)
                                    .stroke(alarm.mission == m ? Color.riseGold : Color.gray.opacity(0.2), lineWidth: alarm.mission == m ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    Text(alarm.mission.blurb).font(.footnote).foregroundStyle(.secondary)
                    if alarm.mission.hasAmount {
                        Stepper(value: $alarm.amount, in: 1...100) {
                            Text("\(alarm.amount) \(alarm.mission.unit)")
                        }
                    }
                    if alarm.mission == .math {
                        Picker("Difficulty", selection: $alarm.level) {
                            ForEach(MathLevel.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Sound") {
                    NavigationLink {
                        SoundPickerView(selection: $alarm.sound)
                    } label: {
                        LabeledContent("Alarm sound", value: SoundLibrary.displayName(alarm.sound))
                    }
                }

                Section("Label") {
                    TextField("Work", text: $alarm.label)
                }

                Section {
                    Button("Try this mission now") {
                        let a = alarm
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { store.startTest(a) }
                    }
                    if !isNew {
                        Button(confirmDelete ? "Tap again to delete" : "Delete alarm", role: .destructive) {
                            if confirmDelete { store.delete(alarm); dismiss() } else { confirmDelete = true }
                        }
                    }
                }

                #if DEBUG
                Section("Testing") {
                    Button("Ring in 1 minute") {
                        let d = Date().addingTimeInterval(60)
                        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                        alarm.hour = c.hour!; alarm.minute = c.minute!
                        alarm.weekdays = []
                    }
                }
                #endif
            }
            .navigationTitle(isNew ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        alarm.enabled = true
                        store.upsert(alarm)
                        dismiss()
                    }.bold()
                }
            }
            .tint(.riseGold)
        }
    }
}
