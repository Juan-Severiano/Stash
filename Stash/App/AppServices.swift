//
//  AppServices.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation
import GRDB
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppServices {
    static let shared = AppServices()

    let settings = SettingsStore()
    let focusManager = FocusManager()
    let screenshotCapture = ScreenshotCapture()
    let panel = ClipboardPanelController()

    private(set) var db: DatabaseQueue?
    private(set) var history: HistoryStore!
    private(set) var collections: CollectionStore!
    private(set) var monitor: ClipboardMonitor!
    private(set) var retention: RetentionService!
    private(set) var screenshotWatcher: ScreenshotWatcher!
    private(set) var paste: PasteService!
    private(set) var hotkeys: GlobalHotkeyManager!

    private init() {}

    func bootstrap() {
        do {
            let db = try StashDatabase.open()
            self.db = db

            history = HistoryStore(db: db)
            collections = CollectionStore(db: db)
            paste = PasteService(settings: settings, focusManager: focusManager, store: history)
            monitor = ClipboardMonitor(settings: settings, store: history)
            retention = RetentionService(db: db, store: history)
            screenshotWatcher = ScreenshotWatcher(settings: settings, store: history)
            hotkeys = GlobalHotkeyManager(settings: settings)

            panel.setContentView(ClipboardPanelView())
            panel.onClose = { [weak self] in
                self?.focusManager.restorePrevious()
            }

            history.loadAll()
            collections.load()
            monitor.start()
            hotkeys.refresh()
            retention.schedule()
            if settings.monitorScreenshots {
                screenshotWatcher.start()
            }
            applyLaunchAtLogin()
        } catch {
            NSLog("Stash bootstrap failed: \(error)")
        }
    }

    // MARK: - Launch at login

    func applyLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if settings.launchAtLogin, SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            } else if !settings.launchAtLogin, SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("SMAppService error: \(error)")
        }
    }

    func launchAtLoginStatusText() -> String {
        guard #available(macOS 13.0, *) else { return "Unavailable" }
        switch SMAppService.mainApp.status {
        case .enabled: return "Enabled"
        case .requiresApproval: return "Requires approval in System Settings"
        case .notFound, .notRegistered: return "Registering works when Stash runs from /Applications"
        @unknown default: return "Unknown"
        }
    }
}
