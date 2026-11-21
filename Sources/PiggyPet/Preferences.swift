import AppKit

/// How often the pig wanders off on its own. Menu-visible titles are Chinese;
/// raw values stay ASCII so the preference is stable across locales.
enum Excitement: String, CaseIterable {
    case low, medium, high

    var title: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }

    var strollInterval: ClosedRange<TimeInterval> {
        switch self {
        case .low: return 180...300
        case .medium: return 45...90
        case .high: return 12...30
        }
    }
}

/// How often an automatic activity turns into a cursor nudge instead of a
/// plain stroll. Strolling is always the default outcome.
enum NudgeFrequency: String, CaseIterable {
    case never, occasionally, often

    var title: String {
        switch self {
        case .never: return "从不"
        case .occasionally: return "偶尔"
        case .often: return "经常"
        }
    }

    var chaseProbability: Double {
        switch self {
        case .never: return 0
        case .occasionally: return 0.2
        case .often: return 0.6
        }
    }
}

/// How fast the pig ambles around on its own. Chasing the cursor always uses
/// the fast running art, independent of this setting.
enum WalkPace: String, CaseIterable {
    case slow, normal, fast

    var title: String {
        switch self {
        case .slow: return "慢悠悠"
        case .normal: return "正常"
        case .fast: return "利索"
        }
    }

    /// Points per second while strolling.
    var pointsPerSecond: CGFloat {
        switch self {
        case .slow: return 48
        case .normal: return 80
        case .fast: return 120
        }
    }
}

/// Thin UserDefaults wrapper. Values are read at use time so `defaults write`
/// from a terminal can tweak behavior after a relaunch.
@MainActor
enum Preferences {
    private enum Key {
        static let originX = "petOriginX"
        static let originY = "petOriginY"
        static let tantrumEnabled = "tantrumEnabled"
        static let bubbleEnabled = "bubbleEnabled"
        static let tantrumIntervalMin = "tantrumIntervalMin"
        static let tantrumIntervalMax = "tantrumIntervalMax"
        static let excitement = "excitementLevel"
        static let nudgeFrequency = "nudgeFrequency"
        static let walkPace = "walkPace"
    }

    private static let defaults: [String: Any] = [
        Key.tantrumEnabled: false,
        Key.bubbleEnabled: true,
        Key.tantrumIntervalMin: 60.0,
        Key.tantrumIntervalMax: 180.0,
        Key.excitement: Excitement.medium.rawValue,
        Key.nudgeFrequency: NudgeFrequency.occasionally.rawValue,
        Key.walkPace: WalkPace.normal.rawValue,
    ]

    static func register() {
        UserDefaults.standard.register(defaults: defaults)
    }

    static var savedOrigin: NSPoint? {
        let values = UserDefaults.standard.dictionaryRepresentation()
        guard let x = values[Key.originX] as? Double,
              let y = values[Key.originY] as? Double else { return nil }
        return NSPoint(x: x, y: y)
    }

    static func saveOrigin(_ origin: NSPoint) {
        UserDefaults.standard.set(Double(origin.x), forKey: Key.originX)
        UserDefaults.standard.set(Double(origin.y), forKey: Key.originY)
    }

    static func clearOrigin() {
        UserDefaults.standard.removeObject(forKey: Key.originX)
        UserDefaults.standard.removeObject(forKey: Key.originY)
    }

    static var tantrumEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.tantrumEnabled)
    }

    static func setTantrumEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Key.tantrumEnabled)
    }

    static var bubbleEnabled: Bool {
        UserDefaults.standard.bool(forKey: Key.bubbleEnabled)
    }

    static func setBubbleEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Key.bubbleEnabled)
    }

    static var tantrumInterval: ClosedRange<TimeInterval> {
        let min = UserDefaults.standard.double(forKey: Key.tantrumIntervalMin)
        let max = UserDefaults.standard.double(forKey: Key.tantrumIntervalMax)
        let lo = min > 0 ? min : 60
        let hi = max > lo ? max : lo + 120
        return lo...hi
    }

    static var excitement: Excitement {
        let raw = UserDefaults.standard.string(forKey: Key.excitement) ?? ""
        return Excitement(rawValue: raw) ?? .medium
    }

    static func setExcitement(_ value: Excitement) {
        UserDefaults.standard.set(value.rawValue, forKey: Key.excitement)
    }

    static var nudgeFrequency: NudgeFrequency {
        let raw = UserDefaults.standard.string(forKey: Key.nudgeFrequency) ?? ""
        return NudgeFrequency(rawValue: raw) ?? .occasionally
    }

    static func setNudgeFrequency(_ value: NudgeFrequency) {
        UserDefaults.standard.set(value.rawValue, forKey: Key.nudgeFrequency)
    }

    static var walkPace: WalkPace {
        let raw = UserDefaults.standard.string(forKey: Key.walkPace) ?? ""
        return WalkPace(rawValue: raw) ?? .normal
    }

    static func setWalkPace(_ value: WalkPace) {
        UserDefaults.standard.set(value.rawValue, forKey: Key.walkPace)
    }
}
