import SwiftUI
import AVFoundation
import Vision
import CoreMotion

/// Live rep counter: front camera + Apple's body-pose detection.
/// Measures the elbow (push-ups) or knee (squats) angle on every frame.
/// A rep counts when the joint bends past `down` and straightens past `up`.
final class PoseCounter: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var reps = 0
    @Published var angle: Double?
    @Published var status = "Starting the camera…"
    @Published var seeing = false
    @Published var cameraDenied = false

    let session = AVCaptureSession()
    let mission: Mission
    let target: Int
    let down: Double
    let up: Double
    var onFinished: ((Int) -> Void)?

    private let queue = DispatchQueue(label: "rise.pose")
    private let motion = CMMotionManager()
    private var gravity = CMAcceleration(x: 0, y: -1, z: 0)
    private let speech = AVSpeechSynthesizer()

    // Rep state (main thread)
    private var phase = 0 // 0 wait for straight, 1 up, 2 dipping
    private var minDeg = 180.0
    private var recent: [Double] = []
    private var finished = false

    // Orientation search (camera queue)
    private var lastFrame = Date.distantPast
    private var misses = 0
    private var orientationIndex = 0
    private var locked = false

    init(mission: Mission, target: Int) {
        self.mission = mission
        self.target = target
        self.down = mission == .squats ? 100 : 100
        self.up = mission == .squats ? 155 : 150
    }

    func start() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async {
                guard ok else { self.cameraDenied = true; self.status = "Camera access is off."; return }
                self.configure()
            }
        }
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 0.2
            motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
                if let g = m?.gravity { self?.queue.async { self?.gravity = g } }
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) else {
            status = "Couldn't open the front camera."; session.commitConfiguration(); return
        }
        session.addInput(input)
        let out = AVCaptureVideoDataOutput()
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(out) { session.addOutput(out) }
        session.commitConfiguration()
        queue.async { self.session.startRunning() }
        status = mission == .squats
            ? "Stand the phone up about 2 m away, side-on to you, head to feet in shot."
            : "Stand the phone on its side about 1.5 m away, side-on to you, whole body in shot."
        speak(mission == .squats ? "Get into position, side on." : "Get into position, side on to the phone.")
    }

    /// Orientations to try, best guess first (from which way the phone is held).
    private func candidates() -> [CGImagePropertyOrientation] {
        let g = gravity
        let guess: CGImagePropertyOrientation = abs(g.y) >= abs(g.x)
            ? (g.y < 0 ? .leftMirrored : .rightMirrored)
            : (g.x < 0 ? .downMirrored : .upMirrored)
        return [guess] + [.leftMirrored, .rightMirrored, .upMirrored, .downMirrored].filter { $0 != guess }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastFrame) > 0.08 else { return } // ~12 fps
        lastFrame = now
        guard let px = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let list = candidates()
        if !locked { orientationIndex = min(orientationIndex, list.count - 1) }
        let orient = locked ? list[0] : list[orientationIndex]

        let req = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: px, orientation: orient)
        try? handler.perform([req])

        var w = Double(CVPixelBufferGetWidth(px)), h = Double(CVPixelBufferGetHeight(px))
        if [.left, .right, .leftMirrored, .rightMirrored].contains(orient) { swap(&w, &h) }

        var deg: Double? = nil
        if let obs = req.results?.first {
            deg = jointAngle(obs, w: w, h: h)
        }
        if deg == nil {
            misses += 1
            if misses > 10 { misses = 0; locked = false; orientationIndex = (orientationIndex + 1) % list.count }
        } else {
            misses = 0
            if orientationIndex == 0 { locked = true }
        }
        DispatchQueue.main.async { self.feed(deg) }
    }

    private func jointAngle(_ obs: VNHumanBodyPoseObservation, w: Double, h: Double) -> Double? {
        typealias J = VNHumanBodyPoseObservation.JointName
        let sides: [[J]] = mission == .squats
            ? [[.leftHip, .leftKnee, .leftAnkle], [.rightHip, .rightKnee, .rightAnkle]]
            : [[.leftShoulder, .leftElbow, .leftWrist], [.rightShoulder, .rightElbow, .rightWrist]]
        guard let pts = try? obs.recognizedPoints(.all) else { return nil }
        var best: (conf: Float, p: [VNRecognizedPoint])?
        for side in sides {
            let p = side.compactMap { pts[$0] }
            guard p.count == 3 else { continue }
            let c = p.map(\.confidence).min() ?? 0
            if c > 0.3, c > (best?.conf ?? 0) { best = (c, p) }
        }
        guard let p = best?.p else { return nil }
        let a = CGPoint(x: p[0].location.x * w, y: p[0].location.y * h)
        let b = CGPoint(x: p[1].location.x * w, y: p[1].location.y * h)
        let c = CGPoint(x: p[2].location.x * w, y: p[2].location.y * h)
        var d = abs(atan2(a.y - b.y, a.x - b.x) - atan2(c.y - b.y, c.x - b.x)) * 180 / .pi
        if d > 180 { d = 360 - d }
        return Double(d)
    }

    // Main thread
    private func feed(_ raw: Double?) {
        guard !finished else { return }
        guard let raw else {
            seeing = false
            if phase == 0 { status = mission == .squats ? "I can't see your legs yet. Move the phone back so hips, knees and ankles are in shot." : "I can't see your arm yet. Move the phone back so shoulder, elbow and wrist are in shot." }
            return
        }
        seeing = true
        recent.append(raw); if recent.count > 3 { recent.removeFirst() }
        let a = recent.sorted()[recent.count / 2]
        angle = a
        switch phase {
        case 0:
            if a > up { phase = 1; status = "Go! Bend past \(Int(down))°, then straighten."; speak("Go") }
        case 1:
            if a < up - 10 { phase = 2; minDeg = a }
        default:
            minDeg = min(minDeg, a)
            if a > up {
                phase = 1
                if minDeg <= down {
                    reps += 1
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    if reps >= target { finished = true; stop(); onFinished?(reps); return }
                    speak("\(reps)"); status = "Good rep."
                } else if minDeg < up - 15 {
                    speak("Deeper"); status = "Too shallow: \(Int(minDeg))°. Get past \(Int(down))°."
                }
            }
        }
    }

    private func speak(_ s: String) {
        speech.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: s); u.rate = 0.55
        speech.speak(u)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.preview.session = session
        v.preview.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

struct PoseMissionView: View {
    let mission: Mission
    let target: Int
    let onDone: (Int) -> Void
    @StateObject private var counter: PoseCounter

    init(mission: Mission, target: Int, onDone: @escaping (Int) -> Void) {
        self.mission = mission
        self.target = target
        self.onDone = onDone
        _counter = StateObject(wrappedValue: PoseCounter(mission: mission, target: target))
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                CameraPreview(session: counter.session)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                HStack(alignment: .top) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(counter.reps)").font(.system(size: 64, weight: .black)).monospacedDigit()
                        Text("/ \(target)").font(.title2.bold())
                    }
                    .foregroundStyle(.white).shadow(radius: 6)
                    Spacer()
                    Text(counter.angle.map { "\(Int($0))°" } ?? "–°")
                        .font(.title3.bold()).monospacedDigit()
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(counter.seeing ? Color.riseGold : Color.black.opacity(0.4)))
                        .foregroundStyle(.white)
                }
                .padding(14)
            }
            .frame(maxHeight: .infinity)
            ProgressView(value: Double(counter.reps), total: Double(target)).tint(.riseGold)
            Text(counter.status).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if counter.cameraDenied {
                Button("Open Settings to allow the camera") {
                    if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                }.tint(.riseGold)
            }
            Text("A rep counts when your \(mission == .squats ? "knee" : "elbow") bends past \(Int(counter.down))° and straightens past \(Int(counter.up))°.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .onAppear {
            counter.onFinished = { n in onDone(n) }
            counter.start()
        }
        .onDisappear { counter.stop() }
    }
}
