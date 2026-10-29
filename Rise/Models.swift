import Foundation

enum Mission: String, Codable, CaseIterable, Identifiable {
    case pushups, squats, math, object, sky, bed, affirm
    var id: String { rawValue }

    var name: String {
        switch self {
        case .pushups: return "Push Ups"
        case .squats: return "Squats"
        case .math: return "Math"
        case .object: return "Object Hunt"
        case .sky: return "Sky Photo"
        case .bed: return "Make Bed"
        case .affirm: return "Affirmation"
        }
    }

    var symbol: String {
        switch self {
        case .pushups: return "figure.strengthtraining.functional"
        case .squats: return "figure.cross.training"
        case .math: return "x.squareroot"
        case .object: return "camera.viewfinder"
        case .sky: return "cloud.sun.fill"
        case .bed: return "bed.double.fill"
        case .affirm: return "text.quote"
        }
    }

    var hasAmount: Bool { self == .pushups || self == .squats || self == .math }
    var isPose: Bool { self == .pushups || self == .squats }

    var defaultAmount: Int {
        switch self {
        case .pushups: return 10
        case .squats: return 15
        case .math: return 3
        default: return 1
        }
    }

    var unit: String {
        switch self {
        case .pushups: return "push-ups"
        case .squats: return "squats"
        case .math: return "problems"
        default: return ""
        }
    }

    var blurb: String {
        switch self {
        case .pushups, .squats: return "The camera counts your reps live."
        case .math: return "Solve sums while the alarm keeps ringing."
        case .object: return "Find a random object and photograph it."
        case .sky: return "Get to a window and photograph the sky."
        case .bed: return "Make your bed, then photograph it."
        case .affirm: return "Type out a short affirmation exactly."
        }
    }
}

enum MathLevel: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct WakeAlarm: Identifiable, Codable, Equatable {
    var id = UUID()
    var hour: Int = 7
    var minute: Int = 0
    /// 1 = Sunday … 7 = Saturday (Calendar weekday numbering). Empty = once.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var label: String = "Wake up"
    var enabled: Bool = true
    var mission: Mission = .pushups
    var amount: Int = 10
    var level: MathLevel = .medium
    /// Sound file name (bundled or imported), or nil for the system default.
    var sound: String? = "siren.caf"

    var timeString: String {
        let d = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
        return d.formatted(date: .omitted, time: .shortened)
    }

    var repeatString: String {
        if weekdays.isEmpty { return "Once" }
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        if weekdays.count == 7 { return "Every day" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
    }

    /// Next time this alarm will ring after `from`.
    func nextFire(after from: Date = .now) -> Date? {
        let cal = Calendar.current
        for offset in 0..<8 {
            guard let day = cal.date(byAdding: .day, value: offset, to: from),
                  let t = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  t > from else { continue }
            if weekdays.isEmpty || weekdays.contains(cal.component(.weekday, from: t)) { return t }
        }
        return nil
    }
}

struct WakeRecord: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var label: String
    var mission: Mission
    var amount: Int
    var seconds: Int
    var skipped: Bool = false
    var sleepHours: Double? = nil
}

/// A mission that is on screen right now.
struct ActiveMission: Identifiable, Equatable {
    var id = UUID()
    var alarm: WakeAlarm
    var test: Bool
}
