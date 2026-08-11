//
//  MenuBar.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import SwiftUI

struct StashMenuBarContent: View {
    private var services: AppServices { AppServices.shared }
    private var settings: SettingsStore { services.settings }
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Open Clipboard") {
            services.panel.show()
        }
        .keyboardShortcut("v", modifiers: .option)

        let recent = services.history?.recentItems(limit: 8) ?? []
        if !recent.isEmpty {
            Divider()
            ForEach(recent) { item in
                Button(menuItemTitle(for: item)) {
                    services.paste.perform(item, mode: .paste)
                }
            }
        }

        Divider()

        if settings.isPaused {
            Button("Resume History") {
                settings.resume()
            }
        } else {
            Button("Pause History") {
                settings.pause(for: 60 * 60)
            }
        }
        Menu("Pause for…") {
            Button("5 minutes") { settings.pause(for: 5 * 60) }
            Button("30 minutes") { settings.pause(for: 30 * 60) }
            Button("1 hour") { settings.pause(for: 60 * 60) }
            Button("Until tomorrow") { settings.pauseUntilTomorrow() }
        }
        Button("Clear History") {
            services.history.deleteAll()
        }

        Divider()

        Button("History Window") {
            openWindow(id: "history")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Settings…") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit Stash") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func menuItemTitle(for item: ClipboardItem) -> String {
        var title = item.displayText
        title = title.replacingOccurrences(of: "\n", with: " ")
        if title.count > 60 {
            title = String(title.prefix(60)) + "…"
        }
        return title
    }
}
