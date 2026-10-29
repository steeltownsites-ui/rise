import SwiftUI
import Vision
import UIKit

// MARK: - Math

struct MathMissionView: View {
    let count: Int
    let level: MathLevel
    let onDone: () -> Void
    @State private var solved = 0
    @State private var problem = MathMissionView.make(.medium)
    @State private var entry = ""
    @State private var shake = false

    static func make(_ level: MathLevel) -> (q: String, a: Int) {
        switch level {
        case .easy:
            let a = Int.random(in: 12...59), b = Int.random(in: 12...49); return ("\(a) + \(b)", a + b)
        case .medium:
            let a = Int.random(in: 12...29), b = Int.random(in: 3...9); return ("\(a) × \(b)", a * b)
        case .hard:
            let a = Int.random(in: 13...39), b = Int.random(in: 4...9), c = Int.random(in: 11...99); return ("\(a) × \(b) + \(c)", a * b + c)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: Double(solved), total: Double(count)).tint(.riseGold)
            Text("Problem \(solved + 1) of \(count)").foregroundStyle(.secondary)
            Text(problem.q).font(.system(size: 52, weight: .black)).monospacedDigit()
            Text(entry.isEmpty ? " " : entry)
                .font(.system(size: 34, weight: .heavy)).monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 2) }
                .offset(x: shake ? 10 : 0)
                .animation(.default.repeatCount(3, autoreverses: true), value: shake)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(["1","2","3","4","5","6","7","8","9","⌫","0","OK"], id: \.self) { k in
                    Button { press(k) } label: {
                        Text(k).font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(RoundedRectangle(cornerRadius: 16).fill(k == "OK" ? Color.primary : Color.riseCard))
                            .foregroundStyle(k == "OK" ? Color.riseBG : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { problem = Self.make(level) }
    }

    private func press(_ k: String) {
        switch k {
        case "⌫": entry = String(entry.dropLast())
        case "OK":
            guard let v = Int(entry) else { return }
            if v == problem.a {
                solved += 1; entry = ""
                if solved >= count { onDone() } else { problem = Self.make(level) }
            } else {
                entry = ""; shake.toggle()
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        default: if entry.count < 5 { entry += k }
        }
    }
}

// MARK: - Affirmation

struct AffirmationMissionView: View {
    let onDone: () -> Void
    @State private var text = AffirmationMissionView.lines.randomElement()!
    @State private var typed = ""
    @FocusState private var focused: Bool

    static let lines = ["I am awake and I am ready for today",
                        "Today I keep the promises I make to myself",
                        "Discipline is choosing what I want most",
                        "I get up because my goals are waiting",
                        "Small wins every morning add up",
                        "I finish what I start",
                        "Every morning is a fresh start"]

    private func norm(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0 == " " }.split(separator: " ").joined(separator: " ")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Type this exactly").foregroundStyle(.secondary)
            Text(text).font(.system(size: 26, weight: .heavy)).multilineTextAlignment(.center)
                .foregroundStyle(norm(text).hasPrefix(norm(typed)) ? Color.primary : .red)
            TextField("Start typing…", text: $typed, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.riseCard))
                .focused($focused)
                .onChange(of: typed) { _, v in if norm(v) == norm(text) { onDone() } }
            Spacer()
        }
        .onAppear { focused = true }
    }
}

// MARK: - Photo missions (checked on the phone with Apple's image recognition)

struct PhotoMissionView: View {
    let kind: Mission
    let onDone: () -> Void

    static let objects: [(name: String, ids: [String])] = [
        ("a coffee mug", ["mug", "cup", "coffee", "teacup"]),
        ("your toothbrush", ["toothbrush"]),
        ("the kettle", ["kettle", "teapot"]),
        ("the fridge", ["refrigerator"]),
        ("a pair of shoes", ["shoes", "shoe", "sneaker", "footwear", "boot"]),
        ("the bathroom sink", ["sink", "bathroom", "washbasin", "faucet"]),
        ("a book", ["book", "books"]),
        ("a houseplant", ["houseplant", "plant", "potted_plant", "flowerpot"]),
        ("a water bottle", ["bottle", "water_bottle"]),
        ("a towel", ["towel"]),
        ("the oven", ["oven", "stove"]),
        ("a spoon", ["spoon", "utensil", "cutlery"]),
        ("a chair", ["chair"]),
        ("the television", ["television", "tv", "monitor"]),
    ]
    static let skyIDs = ["sky", "blue_sky", "cloudy", "clouds", "sunset_sunrise", "overcast"]
    static let bedIDs = ["bed", "bedroom", "bedding", "pillow", "quilt"]

    @State private var target = PhotoMissionView.objects.randomElement()!
    @State private var spins = 2
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var verdict: String?
    @State private var good = false
    @State private var supported: Set<String>?

    private var ids: [String] {
        switch kind {
        case .sky: return Self.skyIDs
        case .bed: return Self.bedIDs
        default: return target.ids
        }
    }

    private var prompt: AttributedString {
        var s: AttributedString
        switch kind {
        case .sky: s = AttributedString("Take a photo of the sky to turn off your alarm")
        case .bed: s = AttributedString("Make your bed, then take a photo of it")
        default: s = AttributedString("Take a photo of \(target.name) to turn off your alarm")
        }
        return s
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(prompt)
                .font(.headline).multilineTextAlignment(.center)
                .padding(16).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.16)))
                .foregroundStyle(.white)
            if kind == .object {
                Button("↻ Respin (\(spins) left)") {
                    spins -= 1
                    target = availableObjects.filter { $0.name != target.name }.randomElement() ?? target
                    image = nil; verdict = nil
                }
                .disabled(spins == 0).tint(.riseGold)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Color.riseCard)
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Text("Your photo appears here").foregroundStyle(.secondary)
                }
            }
            .frame(maxHeight: 380)
            if let verdict {
                Text(verdict).font(.subheadline.bold()).foregroundStyle(good ? .green : .red).multilineTextAlignment(.center)
            }
            Button { showCamera = true } label: {
                Circle().strokeBorder(Color.gray.opacity(0.35), lineWidth: 5)
                    .background(Circle().fill(Color.riseCard))
                    .frame(width: 78, height: 78)
            }
            .accessibilityLabel("Take photo")
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in
                showCamera = false
                if let img { image = img; check(img) }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if supported == nil {
                supported = Set((try? VNClassifyImageRequest().supportedIdentifiers()) ?? [])
                target = availableObjects.randomElement() ?? target
            }
        }
    }

    private var availableObjects: [(name: String, ids: [String])] {
        guard let supported, !supported.isEmpty else { return Self.objects }
        let ok = Self.objects.filter { $0.ids.contains(where: supported.contains) }
        return ok.isEmpty ? Self.objects : ok
    }

    private func check(_ img: UIImage) {
        verdict = "Checking…"; good = false
        let wanted = Set(ids)
        let usable = supported.map { !wanted.isDisjoint(with: $0) } ?? false
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cg = img.cgImage else { return }
            let req = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: CGImagePropertyOrientation(img.imageOrientation))
            try? handler.perform([req])
            let obs = (req.results ?? []).filter { $0.confidence > 0.1 }
            let hit = obs.contains { wanted.contains($0.identifier) }
            let seen = obs.prefix(3).map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
            DispatchQueue.main.async {
                if hit || !usable {
                    good = true
                    verdict = usable ? "Got it. Good morning." : "Photo taken."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDone() }
                } else {
                    verdict = seen.isEmpty ? "I couldn't make that out. Try again in better light."
                        : "That looks like \(seen.joined(separator: ", ")). Try again."
                }
            }
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPick(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onPick(nil) }
    }
}
