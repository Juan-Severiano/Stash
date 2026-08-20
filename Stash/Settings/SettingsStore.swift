//
//  SettingsStore.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    private enum DefaultHotkeys {
        static let open = "\(9)|\(NSEvent.ModifierFlags.option.rawValue)"
        static let screenshot = "\(21)|\(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.shift.rawValue)"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restoreInvalidHotkeys()
    }

    // MARK: - Storage helpers

    private func bool(_ key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private func int(_ key: String, default defaultValue: Int) -> Int {
        defaults.object(forKey: key) as? Int ?? defaultValue
    }

    private func string(_ key: String, default defaultValue: String) -> String {
        defaults.string(forKey: key) ?? defaultValue
    }

    private func stringArray(_ key: String, default defaultValue: [String]) -> [String] {
        defaults.stringArray(forKey: key) ?? defaultValue
    }

    // MARK: - General

    var launchAtLogin: Bool {
        get { bool("launchAtLogin", default: false) }
        set { defaults.set(newValue, forKey: "launchAtLogin") }
    }

    var playSounds: Bool {
        get { bool("playSounds", default: true) }
        set { defaults.set(newValue, forKey: "playSounds") }
    }

    var onboardingCompleted: Bool {
        get { bool("onboardingCompleted", default: false) }
        set { defaults.set(newValue, forKey: "onboardingCompleted") }
    }

    // MARK: - Clipboard

    var clipboardEnabled: Bool {
        get { bool("clipboardEnabled", default: true) }
        set { defaults.set(newValue, forKey: "clipboardEnabled") }
    }

    var maxHistorySize: Int {
        get { int("maxHistorySize", default: 1000) }
        set { defaults.set(newValue, forKey: "maxHistorySize") }
    }

    var ignoreDuplicates: Bool {
        get { bool("ignoreDuplicates", default: true) }
        set { defaults.set(newValue, forKey: "ignoreDuplicates") }
    }

    // MARK: - Screenshots

    var monitorScreenshots: Bool {
        get { bool("monitorScreenshots", default: false) }
        set { defaults.set(newValue, forKey: "monitorScreenshots") }
    }

    var copyScreenshotsToClipboard: Bool {
        get { bool("copyScreenshotsToClipboard", default: true) }
        set { defaults.set(newValue, forKey: "copyScreenshotsToClipboard") }
    }

    var keepScreenshotsInHistory: Bool {
        get { bool("keepScreenshotsInHistory", default: true) }
        set { defaults.set(newValue, forKey: "keepScreenshotsInHistory") }
    }

    var deleteScreenshotFileAfterCapture: Bool {
        get { bool("deleteScreenshotFileAfterCapture", default: false) }
        set { defaults.set(newValue, forKey: "deleteScreenshotFileAfterCapture") }
    }

    var screenshotLocation: String {
        get { string("screenshotLocation", default: "") }
        set { defaults.set(newValue, forKey: "screenshotLocation") }
    }

    // MARK: - Shortcuts ("keyCode|flags")

    var hotkeyOpen: String {
        get { string("hotkeyOpen", default: DefaultHotkeys.open) }
        set { defaults.set(newValue, forKey: "hotkeyOpen") }
    }

    var hotkeyScreenshot: String {
        get { string("hotkeyScreenshot", default: DefaultHotkeys.screenshot) }
        set { defaults.set(newValue, forKey: "hotkeyScreenshot") }
    }

    func resetHotkeys() {
        hotkeyOpen = DefaultHotkeys.open
        hotkeyScreenshot = DefaultHotkeys.screenshot
    }

    private func restoreInvalidHotkeys() {
        restoreHotkey("hotkeyOpen", defaultValue: DefaultHotkeys.open)
        restoreHotkey("hotkeyScreenshot", defaultValue: DefaultHotkeys.screenshot)
    }

    private func restoreHotkey(_ key: String, defaultValue: String) {
        guard let stored = defaults.string(forKey: key),
              HotkeyCodec.isValidGlobalShortcut(stored) else {
            if defaults.object(forKey: key) != nil {
                defaults.set(defaultValue, forKey: key)
            }
            return
        }
    }

    // MARK: - Storage / retention

    var keepTextHistoryDays: Int {
        get { int("keepTextHistoryDays", default: 0) }
        set { defaults.set(newValue, forKey: "keepTextHistoryDays") }
    }

    var keepImagesDays: Int {
        get { int("keepImagesDays", default: 7) }
        set { defaults.set(newValue, forKey: "keepImagesDays") }
    }

    var maxStorageMB: Int {
        get { int("maxStorageMB", default: 1024) }
        set { defaults.set(newValue, forKey: "maxStorageMB") }
    }

    // MARK: - Privacy

    var ignoredAppBundleIDs: [String] {
        get { stringArray("ignoredAppBundleIDs", default: []) }
        set { defaults.set(newValue, forKey: "ignoredAppBundleIDs") }
    }

    var ignorePasswords: Bool {
        get { bool("ignorePasswords", default: false) }
        set { defaults.set(newValue, forKey: "ignorePasswords") }
    }

    var ignoreOTPCodes: Bool {
        get { bool("ignoreOTPCodes", default: true) }
        set { defaults.set(newValue, forKey: "ignoreOTPCodes") }
    }

    var otpLifetimeSeconds: Int {
        get { int("otpLifetimeSeconds", default: 60) }
        set { defaults.set(newValue, forKey: "otpLifetimeSeconds") }
    }

    var autoDeleteSensitiveItems: Bool {
        get { bool("autoDeleteSensitiveItems", default: false) }
        set { defaults.set(newValue, forKey: "autoDeleteSensitiveItems") }
    }

    // MARK: - Pause

    var pausedUntil: Date? {
        get { defaults.object(forKey: "pausedUntil") as? Date }
        set { defaults.set(newValue, forKey: "pausedUntil") }
    }

    var isPaused: Bool {
        guard let until = pausedUntil else { return false }
        return until > Date()
    }

    func pause(for duration: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(duration)
    }

    func pauseUntilTomorrow() {
        var components = DateComponents()
        components.day = 1
        components.hour = 6
        components.minute = 0
        pausedUntil = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date().addingTimeInterval(86_400)
    }

    func resume() {
        pausedUntil = nil
    }

    // MARK: - Ignored apps

    func ignoresApp(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        return ignoredAppBundleIDs.contains(bundleID)
    }
}
