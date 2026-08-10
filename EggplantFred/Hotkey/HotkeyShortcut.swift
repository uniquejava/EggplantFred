import AppKit
import Foundation

/// A single modifier that can be double-tapped to invoke the launcher (Alfred-style).
enum ModifierKind: String, Codable, Hashable, CaseIterable {
    case control
    case option
    case shift
    case command

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    var displayName: String { "\(symbol) double tap" }

    var nsFlag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option: return .option
        case .shift: return .shift
        case .command: return .command
        }
    }

    var cgFlag: CGEventFlags {
        switch self {
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .shift: return .maskShift
        case .command: return .maskCommand
        }
    }

    /// Left/right key codes (HIToolbox virtual key codes).
    var keyCodes: Set<Int64> {
        switch self {
        case .control: return [59, 62]
        case .option: return [58, 61]
        case .shift: return [56, 60]
        case .command: return [55, 54]
        }
    }

    static func from(keyCode: Int64) -> ModifierKind? {
        for kind in allCases where kind.keyCodes.contains(keyCode) {
            return kind
        }
        return nil
    }

    /// The other three modifiers — used to reject chords while detecting a pure double-tap.
    var otherCGFlags: CGEventFlags {
        var flags: CGEventFlags = []
        for kind in ModifierKind.allCases where kind != self {
            flags.insert(kind.cgFlag)
        }
        return flags
    }
}

enum HotkeyShortcut: Equatable, Hashable {
    case doubleTap(modifier: ModifierKind)
    case keyCombo(keyCode: UInt16, modifiers: UInt)

    /// Default Alfred-like binding.
    static var doubleOption: HotkeyShortcut { .doubleTap(modifier: .option) }

    var displayName: String {
        switch self {
        case .doubleTap(let modifier):
            return modifier.displayName
        case .keyCombo(let keyCode, let modifiers):
            return Self.describe(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiers))
        }
    }

    var doubleTapModifier: ModifierKind? {
        if case .doubleTap(let modifier) = self { return modifier }
        return nil
    }

    static func describe(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    private static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "↩"
        case 53: return "Esc"
        case 48: return "⇥"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            if let map = Self.keyMap[keyCode] {
                return map
            }
            return "Key\(keyCode)"
        }
    }

    private static let keyMap: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y",
        17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
        25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
        33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`"
    ]
}

extension HotkeyShortcut: Codable {
    private enum CodingKeys: String, CodingKey {
        case doubleTap
        case doubleOption // legacy
        case keyCombo
    }

    private enum DoubleTapKeys: String, CodingKey {
        case modifier
    }

    private enum KeyComboKeys: String, CodingKey {
        case keyCode
        case modifiers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .doubleTap(let modifier):
            var nested = container.nestedContainer(keyedBy: DoubleTapKeys.self, forKey: .doubleTap)
            try nested.encode(modifier, forKey: .modifier)
        case .keyCombo(let keyCode, let modifiers):
            var nested = container.nestedContainer(keyedBy: KeyComboKeys.self, forKey: .keyCombo)
            try nested.encode(keyCode, forKey: .keyCode)
            try nested.encode(modifiers, forKey: .modifiers)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.doubleTap) {
            let nested = try container.nestedContainer(keyedBy: DoubleTapKeys.self, forKey: .doubleTap)
            let modifier = try nested.decode(ModifierKind.self, forKey: .modifier)
            self = .doubleTap(modifier: modifier)
        } else if container.contains(.doubleOption) {
            // Migrate older builds that only stored `doubleOption`.
            self = .doubleTap(modifier: .option)
        } else if container.contains(.keyCombo) {
            let nested = try container.nestedContainer(keyedBy: KeyComboKeys.self, forKey: .keyCombo)
            let keyCode = try nested.decode(UInt16.self, forKey: .keyCode)
            let modifiers = try nested.decode(UInt.self, forKey: .modifiers)
            self = .keyCombo(keyCode: keyCode, modifiers: modifiers)
        } else {
            self = .doubleTap(modifier: .option)
        }
    }
}

@MainActor
final class HotkeySettings: ObservableObject {
    private static let key = "hotkeyShortcut"

    @Published var shortcut: HotkeyShortcut {
        didSet { persist() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(HotkeyShortcut.self, from: data) {
            shortcut = decoded
        } else {
            shortcut = .doubleOption
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
