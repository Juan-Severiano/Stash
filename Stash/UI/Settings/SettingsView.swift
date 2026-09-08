//
//  SettingsView.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import SwiftUI

struct SettingsView: View {
    private enum SettingsSection: String, CaseIterable, Identifiable {
        case general, clipboard, screenshots, shortcuts, privacy, storage, collections, about

        var id: Self { self }

        var title: String {
            switch self {
            case .general: "General"
            case .clipboard: "Clipboard"
            case .screenshots: "Screenshots"
            case .shortcuts: "Shortcuts"
            case .privacy: "Privacy"
            case .storage: "Storage"
            case .collections: "Collections"
            case .about: "About Stash"
            }
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .clipboard: "doc.on.clipboard"
            case .screenshots: "camera"
            case .shortcuts: "keyboard"
            case .privacy: "hand.raised"
            case .storage: "externaldrive"
            case .collections: "folder"
            case .about: "info.circle"
            }
        }

        var summary: String {
            switch self {
            case .general: "Choose how Stash behaves on your Mac."
            case .clipboard: "Control what Stash saves and how it pastes."
            case .screenshots: "Bring captured screenshots into your history."
            case .shortcuts: "Set the shortcuts you use most."
            case .privacy: "Keep sensitive information out of your history."
            case .storage: "Manage how long Stash keeps your items."
            case .collections: "Organize your most useful snippets."
            case .about: "Everything you copied is one shortcut away."
            }
        }

        static let preferences: [Self] = [.general, .clipboard, .screenshots, .shortcuts]
        static let data: [Self] = [.collections, .storage, .privacy]
    }

    @State private var selection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Preferences") {
                    ForEach(SettingsSection.preferences) { section in
                        sidebarRow(for: section)
                    }
                }

                Section("Data") {
                    ForEach(SettingsSection.data) { section in
                        sidebarRow(for: section)
                    }
                }

                Section {
                    sidebarRow(for: .about)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Settings")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            settingsDetail
        }
        .frame(width: 780, height: 500)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func sidebarRow(for section: SettingsSection) -> some View {
        Label(section.title, systemImage: section.icon)
            .tag(section)
    }

    private var settingsDetail: some View {
        let section = selection ?? .general

        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text(section.title)
                    .font(.title2.weight(.semibold))
                Text(section.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            selectedSettingsView(for: section)
        }
        .frame(maxWidth: 580, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func selectedSettingsView(for section: SettingsSection) -> some View {
        switch section {
        case .general: GeneralSettingsView()
        case .clipboard: ClipboardSettingsView()
        case .screenshots: ScreenshotsSettingsView()
        case .shortcuts: ShortcutsSettingsView()
        case .privacy: PrivacySettingsView()
        case .storage: StorageSettingsView()
        case .collections: CollectionsSettingsView()
        case .about: AboutSettingsView()
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @Bindable private var settings = AppServices.shared.settings
    private var services: AppServices { AppServices.shared }
    @State private var launchAtLoginStatus = ""

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, _ in
                    services.applyLaunchAtLogin()
                }
            Toggle("Play sounds", isOn: $settings.playSounds)
            Section("Paste") {
                Toggle("Paste automatically after selecting an item", isOn: $settings.autoPaste)
                    .onChange(of: settings.autoPaste) { _, newValue in
                        if newValue {
                            _ = PasteSimulator.isTrusted(prompt: true)
                        }
                    }
                    .help("Requires Accessibility permission so Stash can send ⌘V on your behalf")
                if settings.autoPaste && !PasteSimulator.isTrusted() {
                    HStack {
                        Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open System Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systemsettings:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLoginStatus = services.launchAtLoginStatusText()
        }
    }
}

// MARK: - Clipboard

struct ClipboardSettingsView: View {
    @Bindable private var settings = AppServices.shared.settings

    var body: some View {
        Form {
            Section("History") {
                Toggle("Enable clipboard history", isOn: $settings.clipboardEnabled)
                Toggle("Merge duplicated items", isOn: $settings.ignoreDuplicates)
                    .help("Copies of the same content bump the item to the top instead of creating a new one")
                Picker("Maximum history size", selection: $settings.maxHistorySize) {
                    Text("200 items").tag(200)
                    Text("500 items").tag(500)
                    Text("1,000 items").tag(1000)
                    Text("5,000 items").tag(5000)
                    Text("10,000 items").tag(10000)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Screenshots

struct ScreenshotsSettingsView: View {
    @Bindable private var settings = AppServices.shared.settings
    private var services: AppServices { AppServices.shared }

    var body: some View {
        Form {
            Section("Capture") {
                Toggle("Monitor screenshots (⌘⇧3 / ⌘⇧4 / ⌘⇧5)", isOn: $settings.monitorScreenshots)
                    .onChange(of: settings.monitorScreenshots) { _, newValue in
                        if newValue {
                            services.screenshotWatcher.start()
                        } else {
                            services.screenshotWatcher.stop()
                        }
                    }
                Toggle("Copy screenshots to clipboard automatically", isOn: $settings.copyScreenshotsToClipboard)
                Toggle("Keep screenshots in history", isOn: $settings.keepScreenshotsInHistory)
                Toggle("Delete screenshot file after capture", isOn: $settings.deleteScreenshotFileAfterCapture)
                    .help("The PNG on disk is removed after Stash stores it")
            }
            Section("Screenshot folder") {
                HStack {
                    TextField("Custom folder", text: $settings.screenshotLocation)
                        .textFieldStyle(.roundedBorder)
                    Button("Reset") {
                        settings.screenshotLocation = ""
                    }
                    .disabled(settings.screenshotLocation.isEmpty)
                }
                Text("Leave empty to use the system screenshot location (default: Desktop).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsView: View {
    @Bindable private var settings = AppServices.shared.settings
    private var services: AppServices { AppServices.shared }

    var body: some View {
        Form {
            Section("Global shortcuts") {
                HStack {
                    Text("Open Clipboard")
                    Spacer()
                    HotkeyRecorderView(value: $settings.hotkeyOpen) {
                        services.hotkeys.refresh()
                    }
                }
                HStack {
                    Text("Take Region Screenshot")
                    Spacer()
                    HotkeyRecorderView(value: $settings.hotkeyScreenshot) {
                        services.hotkeys.refresh()
                    }
                }
            }
            Section {
                Text("The region screenshot shortcut requests Screen Recording permission only when you use it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Restore Default Shortcuts") {
                        settings.resetHotkeys()
                        services.hotkeys.refresh()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy

struct PrivacySettingsView: View {
    @Bindable private var settings = AppServices.shared.settings
    @State private var ignoredApps: [String] = []

    var body: some View {
        Form {
            Section("Ignored Apps") {
                ForEach(ignoredApps, id: \.self) { bundleID in
                    HStack {
                        Text(appName(for: bundleID))
                        Spacer()
                        Text(bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            removeIgnoredApp(bundleID)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Ignore Frontmost App") {
                    addFrontmostApp()
                }
                if ignoredApps.isEmpty {
                    Text("Nothing copied from these apps is stored in your history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Sensitive Content") {
                Toggle("Ignore passwords", isOn: $settings.ignorePasswords)
                    .help("Heuristic: single tokens of 12+ chars with mixed character classes")
                Toggle("Ignore OTP codes", isOn: $settings.ignoreOTPCodes)
                HStack {
                    Text("OTP lifetime")
                    Spacer()
                    Picker("", selection: $settings.otpLifetimeSeconds) {
                        Text("30 seconds").tag(30)
                        Text("60 seconds").tag(60)
                        Text("5 minutes").tag(300)
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
                Toggle("Automatically delete old sensitive items", isOn: $settings.autoDeleteSensitiveItems)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            ignoredApps = settings.ignoredAppBundleIDs
        }
    }

    private func appName(for bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .flatMap { Bundle(url: $0)?.localizedInfoDictionary?["CFBundleName"] as? String }
            ?? bundleID
    }

    private func addFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              !settings.ignoredAppBundleIDs.contains(bundleID) else { return }
        settings.ignoredAppBundleIDs.append(bundleID)
        ignoredApps = settings.ignoredAppBundleIDs
    }

    private func removeIgnoredApp(_ bundleID: String) {
        settings.ignoredAppBundleIDs.removeAll { $0 == bundleID }
        ignoredApps = settings.ignoredAppBundleIDs
    }
}

// MARK: - Storage

struct StorageSettingsView: View {
    @Bindable private var settings = AppServices.shared.settings
    private var services: AppServices { AppServices.shared }
    @State private var usedBytes: Int64 = 0

    var body: some View {
        Form {
            Section("Keep clipboard history") {
                Picker("Text", selection: $settings.keepTextHistoryDays) {
                    Text("24 hours").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("Forever").tag(0)
                }
                Picker("Images", selection: $settings.keepImagesDays) {
                    Text("24 hours").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("Forever").tag(0)
                }
            }
            Section("Maximum storage") {
                Picker("Limit", selection: $settings.maxStorageMB) {
                    Text("500 MB").tag(500)
                    Text("1 GB").tag(1024)
                    Text("5 GB").tag(5120)
                    Text("Unlimited").tag(0)
                }
                .onChange(of: settings.maxStorageMB) { _, _ in
                    services.retention.sweep()
                }
                Text("Oldest unpinned items are removed first. Pinned items are never deleted automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Text("Currently used")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file))
                        .foregroundStyle(.secondary)
                }
                Button("Run Cleanup Now") {
                    services.retention.sweep()
                    usedBytes = FileStorage.totalSize()
                }
                Button("Clear All History", role: .destructive) {
                    services.history.deleteAll()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            usedBytes = FileStorage.totalSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("stash.historyChanged"))) { _ in
            usedBytes = FileStorage.totalSize()
        }
    }
}

// MARK: - Collections

struct CollectionsSettingsView: View {
    private var services: AppServices { AppServices.shared }
    @State private var newName = ""
    @State private var editingID: String?
    @State private var editingName = ""

    var body: some View {
        Form {
            Section("Collections") {
                ForEach(services.collections.collections) { collection in
                    HStack {
                        if editingID == collection.id {
                            TextField("Name", text: $editingName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    services.collections.rename(id: collection.id, name: editingName)
                                    editingID = nil
                                }
                            Button("Save") {
                                services.collections.rename(id: collection.id, name: editingName)
                                editingID = nil
                            }
                        } else {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(collection.name)
                            Spacer()
                            Text("\(collection.itemCount) items")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Rename") {
                                editingID = collection.id
                                editingName = collection.name
                            }
                            .buttonStyle(.borderless)
                            Button {
                                services.collections.delete(id: collection.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                HStack {
                    TextField("New collection name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addCollection)
                    Button("Add") {
                        addCollection()
                    }
                }
                if services.collections.collections.isEmpty {
                    Text("Collections group your most-used snippets. Assign items from the quick actions menu (⌘K) in the clipboard panel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addCollection() {
        services.collections.create(name: newName)
        newName = ""
    }
}

// MARK: - About

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Stash")
                .font(.title2.weight(.semibold))
            Text("Everything you copied is one shortcut away.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link("Privacy Policy", destination: URL(string: "https://stash-clipboard-macos.ivory-sugar-7739.chatgpt.site/privacy")!)
                .font(.callout.weight(.medium))
            Spacer()
            Text("⌥V to open your clipboard")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
