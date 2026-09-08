//
//  PasteSimulator.swift
//  Stash
//

import AppKit

/// Synthesizes a ⌘V keystroke so the item Stash just copied lands directly in
/// the frontmost app, instead of requiring the user to press ⌘V themselves.
/// Requires Accessibility permission to post system-wide key events.
enum PasteSimulator {
    static func isTrusted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func simulatePaste() {
        guard isTrusted() else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode: CGKeyCode = 9 // V
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
