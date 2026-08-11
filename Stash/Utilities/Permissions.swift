//
//  Permissions.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import ApplicationServices
import AppKit

enum Permissions {
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system accessibility prompt (if not already trusted).
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        openSystemPane("Privacy_Accessibility")
    }

    static func openScreenRecordingSettings() {
        openSystemPane("Privacy_ScreenCapture")
    }

    private static func openSystemPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
