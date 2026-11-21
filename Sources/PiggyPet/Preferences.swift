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
    }

    private static let defaults: [String: Any] = [
        Key.tantrumEnabled: false,
        Key.bubbleEnabled: true,
        Key.tantrumIntervalMin: 60.0,
        Key.tantrumIntervalMax: 180.0,
        Key.excitement: Excitement.medium.rawValue,
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
}
