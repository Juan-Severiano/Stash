//
//  PasteService.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import ApplicationServices

@MainActor
final class PasteService {
    enum Mode: Equatable {
        case paste
        case copy
        case pastePlain
        case pasteEditedText(String)
    }

    private let settings: SettingsStore
    private let focusManager: FocusManager
    private let store: HistoryStore

    init(settings: SettingsStore, focusManager: FocusManager, store: HistoryStore) {
        self.settings = settings
        self.focusManager = focusManager
        self.store = store
    }

    /// Writes the item to the clipboard, closes the panel, and (optionally) pastes.
    func perform(_ item: ClipboardItem, mode: Mode) {
        store.markUsed(id: item.id)
        apply(item: item, mode: mode)
        AppServices.shared.panel.hide(restoreFocus: true)
        if settings.playSounds {
            NSSound(named: "Pop")?.play()
        }
    }

    /// Pasting arbitrary text (e.g. edited content) without touching an item.
    func perform(text: String, mode: Mode) {
        apply(text: text, mode: mode)
        AppServices.shared.panel.hide(restoreFocus: true)
        if settings.playSounds {
            NSSound(named: "Pop")?.play()
        }
    }

    /// Global ⌥⇧V: strip formatting from whatever is currently in the clipboard and paste.
    func pasteCurrentClipboardPlain() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        guard !text.isEmpty else { return }
        ClipboardWriter.writePlain(text)
        pasteToFrontmostApp()
        if settings.playSounds {
            NSSound(named: "Pop")?.play()
        }
    }

    // MARK: - Private

    private func apply(item: ClipboardItem, mode: Mode) {
        switch mode {
        case .copy:
            ClipboardWriter.write(item)
        case .paste:
            ClipboardWriter.write(item)
            pasteToFrontmostApp()
        case .pastePlain:
            ClipboardWriter.writePlain(item.textContent ?? item.displayText)
            pasteToFrontmostApp()
        case .pasteEditedText(let text):
            ClipboardWriter.writePlain(text)
            pasteToFrontmostApp()
        }
    }

    private func apply(text: String, mode: Mode) {
        switch mode {
        case .copy, .paste, .pastePlain:
            ClipboardWriter.writePlain(text)
        case .pasteEditedText:
            ClipboardWriter.writePlain(text)
        }
        switch mode {
        case .paste, .pasteEditedText:
            pasteToFrontmostApp()
        default:
            break
        }
    }

    private func pasteToFrontmostApp() {
        focusManager.restorePrevious()
        guard Permissions.isAccessibilityTrusted() else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            PasteService.postCommandV()
        }
    }

    nonisolated static func postCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
