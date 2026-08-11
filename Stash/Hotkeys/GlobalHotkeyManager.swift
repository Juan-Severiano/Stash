//
//  GlobalHotkeyManager.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import HotKey

@MainActor
final class GlobalHotkeyManager {
    private let settings: SettingsStore
    private var openHotkey: HotKey?
    private var plainPasteHotkey: HotKey?
    private var screenshotHotkey: HotKey?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func refresh() {
        let services = AppServices.shared
        openHotkey = make(from: settings.hotkeyOpen) {
            services.panel.show()
        }
        plainPasteHotkey = make(from: settings.hotkeyPastePlain) {
            services.paste.pasteCurrentClipboardPlain()
        }
        screenshotHotkey = make(from: settings.hotkeyScreenshot) {
            services.screenshotCapture.captureRegionToClipboard()
        }
    }

    private func make(from stored: String, action: @escaping () -> Void) -> HotKey? {
        guard let combo = HotkeyCodec.decode(stored),
              HotkeyCodec.hasShortcutModifier(combo.modifiers) else { return nil }
        let hotKey = HotKey(keyCombo: combo)
        hotKey.keyDownHandler = action
        return hotKey
    }
}

enum HotkeyCodec {
    private static let shortcutModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    static func encode(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        "\(keyCode)|\(modifiers.rawValue)"
    }

    static func decode(_ stored: String) -> KeyCombo? {
        let parts = stored.split(separator: "|")
        guard parts.count == 2,
              let code = Int(parts[0]),
              let flags = UInt(parts[1]),
              let key = Key(carbonKeyCode: UInt32(code)) else { return nil }
        return KeyCombo(key: key, modifiers: NSEvent.ModifierFlags(rawValue: flags))
    }

    static func hasShortcutModifier(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        !modifiers.intersection(shortcutModifiers).isEmpty
    }

    static func isValidGlobalShortcut(_ stored: String) -> Bool {
        guard let combo = decode(stored) else { return false }
        return hasShortcutModifier(combo.modifiers)
    }

    static func display(_ stored: String) -> String {
        guard let combo = decode(stored) else { return "—" }
        return KeyDisplay.string(keyCode: Int(combo.carbonKeyCode), modifiers: combo.modifiers)
    }
}

enum KeyDisplay {
    private static let letterMap: [Int: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
        11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
        31: "o", 32: "u", 34: "i", 35: "p", 37: "l", 38: "j", 40: "k", 45: "n", 46: "m",
    ]

    private static let digitMap: [Int: String] = [
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
    ]

    static func symbol(keyCode: Int) -> String {
        if let letter = letterMap[keyCode] { return letter }
        if let digit = digitMap[keyCode] { return digit }
        switch keyCode {
        case 49: return "Space"
        case 36: return "↩"
        case 53: return "⎋"
        case 51: return "⌫"
        case 48: return "⇥"
        case 126: return "↑"
        case 125: return "↓"
        case 123: return "←"
        case 124: return "→"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "\(keyCode)"
        }
    }

    static func string(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        var out = ""
        if modifiers.contains(.control) { out += "⌃" }
        if modifiers.contains(.option) { out += "⌥" }
        if modifiers.contains(.shift) { out += "⇧" }
        if modifiers.contains(.command) { out += "⌘" }
        let symbol = symbol(keyCode: keyCode)
        if symbol.count == 1, symbol.first?.isLowercase == true {
            out += symbol.uppercased()
        } else {
            out += symbol
        }
        return out
    }
}
