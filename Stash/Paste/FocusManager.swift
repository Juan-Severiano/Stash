//
//  FocusManager.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit

/// Tracks the most recent frontmost application so focus can be restored after the panel closes.
@MainActor
final class FocusManager {
    private(set) var lastFrontmostApp: NSRunningApplication?
    private var activateObserver: NSObjectProtocol?
    private var deactivateObserver: NSObjectProtocol?

    init() {
        let center = NSWorkspace.shared.notificationCenter
        activateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.lastFrontmostApp = app
        }
        deactivateObserver = center.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.lastFrontmostApp = app
        }
    }

    /// Captures the current frontmost app explicitly (called right before showing the panel).
    func rememberCurrent() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastFrontmostApp = app
        }
    }

    func restorePrevious() {
        lastFrontmostApp?.activate(options: [.activateIgnoringOtherApps])
    }

    func currentApp() -> (name: String?, bundleID: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.localizedName, app?.bundleIdentifier)
    }
}
