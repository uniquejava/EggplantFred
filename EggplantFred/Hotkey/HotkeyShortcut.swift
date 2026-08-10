import AppKit
import Foundation

enum HotkeyShortcut: Equatable, Codable, Hashable {
    case doubleOption
    case keyCombo(keyCode: UInt16, modifiers: UInt)

    var displayName: String {
        switch self {
        case .doubleOption:
            return "Double Option"
        case .keyCombo(let keyCode, let modifiers):
            return Self.describe(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiers))
        }
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
