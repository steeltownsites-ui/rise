import SwiftUI
import UniformTypeIdentifiers

struct SoundPickerView: View {
    @Binding var selection: String?
    @StateObject private var library = SoundLibrary.shared
    @State private var importing = false
    @State private var startAt = 0
    @State private var error: String?

    var body: some View {
        List {
            Section("Alarm sounds") {
                ForEach(SoundLibrary.builtIns, id: \.file) { row($0.file) }
                row(nil)
            }

            if !library.songs.isEmpty {
                Section {
                    ForEach(library.songs, id: \.self) { row($0) }
                        .onDelete { idx in
                            for i in idx {
                                let f = library.songs[i]
                                if selection == f { selection = "siren.caf" }
                                library.delete(f)
                            }
                        }
                } header: { Text("Your music") } footer: { Text("Swipe left to remove a song.") }
            }

            Section {
                Stepper("Start from \(startAt)s", value: $startAt, in: 0...600, step: 5)
                Button { importing = true } label: { Label("Import song…", systemImage: "square.and.arrow.down") }
            } header: {
                Text("Add music")
            } footer: {
                Text("Pick an MP3, M4A or WAV from Files, iCloud Drive or AirDrop. \(Int(SoundLibrary.maxSeconds)) seconds from the start point are used and loop while the alarm rings. Apple Music downloads are copy-protected and can't be used.")
            }
        }
        .navigationTitle("Alarm Sound")
        .tint(.riseGold)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let name = try library.importSong(from: url, startAt: Double(startAt))
                selection = name
                library.preview(name)
            } catch {
                self.error = "Couldn't import that file. Try an MP3, M4A or WAV that isn't copy-protected."
            }
        }
        .alert("Import failed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
        .onDisappear { library.stopPreview() }
    }

    private func row(_ file: String?) -> some View {
        Button {
            selection = file
            library.preview(file)
        } label: {
            HStack {
                Image(systemName: selection == file ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection == file ? Color.riseGold : .secondary)
                    .font(.title3)
                Text(SoundLibrary.displayName(file)).foregroundStyle(.primary)
                Spacer()
                if file != nil { Image(systemName: "play.circle.fill").foregroundStyle(.secondary).font(.title3) }
            }
        }
    }
}
