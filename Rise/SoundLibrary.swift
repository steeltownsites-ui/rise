import Foundation
import AVFoundation

/// Alarm sounds: six built into the app, plus songs you import.
/// Imports are converted to 30-second .caf clips in Library/Sounds,
/// which is where AlarmKit looks for custom sounds.
/// (Apple Music tracks are copy-protected and can't be used — import
/// MP3/M4A/WAV files from Files, iCloud Drive, AirDrop, etc.)
@MainActor
final class SoundLibrary: ObservableObject {
    static let shared = SoundLibrary()
    nonisolated static let maxSeconds: Double = 30

    static let builtIns: [(file: String, name: String)] = [
        ("siren.caf", "Ultra Loud Siren"),
        ("classic.caf", "Classic Beep"),
        ("digital.caf", "Digital Alarm"),
        ("rising.caf", "Rising Tone"),
        ("chime.caf", "Morning Chime"),
        ("pulse.caf", "Bass Pulse"),
    ]

    @Published private(set) var songs: [String] = []
    private var player: AVAudioPlayer?
    private var ringer: AVAudioPlayer?

    nonisolated static var folder: URL {
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    init() { refresh() }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: Self.folder.path)) ?? []
        songs = files.filter { $0.hasSuffix(".caf") }.sorted()
    }

    static func displayName(_ file: String?) -> String {
        guard let file else { return "iPhone default" }
        if let b = builtIns.first(where: { $0.file == file }) { return b.name }
        return (file as NSString).deletingPathExtension
    }

    static func url(for file: String) -> URL? {
        if let u = Bundle.main.url(forResource: (file as NSString).deletingPathExtension, withExtension: "caf") { return u }
        let u = folder.appendingPathComponent(file)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// Converts and trims a picked file into Library/Sounds. Returns the stored filename.
    func importSong(from source: URL, startAt: Double = 0) throws -> String {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let sr = format.sampleRate
        let startFrame = AVAudioFramePosition(max(0, startAt) * sr)
        guard startFrame < input.length else { throw CocoaError(.fileReadCorruptFile) }
        input.framePosition = startFrame
        let frames = AVAudioFrameCount(min(Double(input.length - startFrame), Self.maxSeconds * sr))

        var base = source.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "/", with: "-")
        if base.isEmpty || Self.builtIns.contains(where: { $0.file == "\(base).caf" }) { base = "Song \(base)" }
        var name = "\(base).caf"
        var n = 2
        while FileManager.default.fileExists(atPath: Self.folder.appendingPathComponent(name).path) {
            name = "\(base) \(n).caf"; n += 1
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sr,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let output = try AVAudioFile(forWriting: Self.folder.appendingPathComponent(name),
                                     settings: settings,
                                     commonFormat: format.commonFormat,
                                     interleaved: format.isInterleaved)
        var remaining = frames
        while remaining > 0 {
            let size = min(8192, remaining)
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: size) else { break }
            try input.read(into: buf, frameCount: size)
            if buf.frameLength == 0 { break }
            try output.write(from: buf)
            remaining -= buf.frameLength
        }
        refresh()
        return name
    }

    func delete(_ file: String) {
        try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(file))
        refresh()
    }

    // MARK: Preview

    func preview(_ file: String?) {
        stopPreview()
        guard let file, let u = Self.url(for: file) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: u)
        player?.play()
    }

    func stopPreview() { player?.stop(); player = nil }

    // MARK: Ringing inside the app (until the mission is done)

    func startRinging(_ file: String?) {
        stopRinging()
        let u = file.flatMap { Self.url(for: $0) } ?? Self.url(for: "siren.caf")
        guard let u else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        ringer = try? AVAudioPlayer(contentsOf: u)
        ringer?.numberOfLoops = -1
        ringer?.volume = 1
        ringer?.play()
    }

    func stopRinging() { ringer?.stop(); ringer = nil }
    var isRinging: Bool { ringer?.isPlaying ?? false }
}
