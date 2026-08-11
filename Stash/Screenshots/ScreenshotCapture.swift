//
//  ScreenshotCapture.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation

/// Runs the built-in `screencapture` tool for custom screenshot hotkeys.
@MainActor
final class ScreenshotCapture {
    /// Interactive region capture straight to the clipboard (no Desktop clutter).
    func captureRegionToClipboard() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c"]
        do {
            try process.run()
        } catch {
            NSLog("screencapture failed: \(error)")
        }
    }
}
