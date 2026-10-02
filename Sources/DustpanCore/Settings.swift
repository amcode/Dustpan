import Foundation

/// A global keyboard shortcut, expressed without AppKit so it can be stored and tested.
public struct HotKey: Equatable, Codable {
    public struct Modifiers: OptionSet, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option  = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift   = Modifiers(rawValue: 1 << 3)
    }

    /// macOS virtual key code (kVK_*).
    public let keyCode: UInt32
    public let modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let keyH: UInt32 = 4      // kVK_ANSI_H
    public static let keyD: UInt32 = 2      // kVK_ANSI_D
    public static let keyM: UInt32 = 46     // kVK_ANSI_M

    /// Offered in the menu. None of these clash with common macOS shortcuts.
    public static let presets: [HotKey] = [
        HotKey(keyCode: keyH, modifiers: [.control, .option]),
        HotKey(keyCode: keyH, modifiers: [.command, .shift]),
        HotKey(keyCode: keyD, modifiers: [.control, .option]),
        HotKey(keyCode: keyM, modifiers: [.control, .option]),
    ]

    /// "⌃ ⌥ H", in the order macOS shows modifiers.
    public var displayName: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined(separator: " ")
    }

    private var keyName: String {
        switch keyCode {
        case Self.keyH: return "H"
        case Self.keyD: return "D"
        case Self.keyM: return "M"
        case 49: return "Space"
        default: return "Key \(keyCode)"
        }
    }
}

/// User settings, persisted in UserDefaults. Injectable suite so tests stay isolated.
public final class Settings {
    public static let delayOptions: [TimeInterval] = [3, 5, 10, 20, 30, 60]
    public static let defaultDelay: TimeInterval = 10

    enum Key {
        static let autoSweep = "autoSweep"
        static let autoSweepDelay = "autoSweepDelay"
        static let sweepAtLaunch = "sweepAtLaunch"
        static let hotKey = "hotKey"
        static let hotKeyEnabled = "hotKeyEnabled"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Sweep the icons away again automatically after showing them. On by default.
    public var autoSweep: Bool {
        get { defaults.object(forKey: Key.autoSweep) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoSweep) }
    }

    /// Seconds the icons stay visible before auto-sweep. Never zero or negative.
    public var autoSweepDelay: TimeInterval {
        get {
            let v = defaults.double(forKey: Key.autoSweepDelay)
            return v > 0 ? v : Self.defaultDelay
        }
        set { defaults.set(max(newValue, 1), forKey: Key.autoSweepDelay) }
    }

    /// Start with the icons swept. On by default.
    public var sweepAtLaunch: Bool {
        get { defaults.object(forKey: Key.sweepAtLaunch) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.sweepAtLaunch) }
    }

    /// The shortcut to toggle, or nil if the user turned it off.
    public var hotKey: HotKey? {
        get {
            guard hotKeyEnabled else { return nil }
            if let data = defaults.data(forKey: Key.hotKey),
               let hk = try? JSONDecoder().decode(HotKey.self, from: data) {
                return hk
            }
            return HotKey.presets[0]
        }
        set {
            if let hk = newValue {
                defaults.set(try? JSONEncoder().encode(hk), forKey: Key.hotKey)
                hotKeyEnabled = true
            } else {
                hotKeyEnabled = false
            }
        }
    }

    private var hotKeyEnabled: Bool {
        get { defaults.object(forKey: Key.hotKeyEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hotKeyEnabled) }
    }
}
