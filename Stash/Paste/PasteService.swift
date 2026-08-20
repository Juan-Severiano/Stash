//
//  PasteService.swift
//  Stash
//

import AppKit

@MainActor
final class PasteService {
    enum Mode: Equatable {
        case copy
        case copyPlain
        case copyEditedText(String)
    }

    private let settings: SettingsStore
    private let store: HistoryStore

    init(settings: SettingsStore, store: HistoryStore) {
        self.settings = settings
        self.store = store
    }

    /// Copies a history item to the system pasteboard. The user pastes manually
    /// in the destination app; Stash does not control other applications.
    func perform(_ item: ClipboardItem, mode: Mode) {
        store.markUsed(id: item.id)
        apply(item: item, mode: mode)
        AppServices.shared.panel.hide(restoreFocus: true)
        if settings.playSounds {
            NSSound(named: "Pop")?.play()
        }
    }

    func perform(text: String, mode: Mode) {
        switch mode {
        case .copy, .copyPlain, .copyEditedText:
            ClipboardWriter.writePlain(text)
        }
        AppServices.shared.panel.hide(restoreFocus: true)
        if settings.playSounds {
            NSSound(named: "Pop")?.play()
        }
    }

    private func apply(item: ClipboardItem, mode: Mode) {
        switch mode {
        case .copy:
            ClipboardWriter.write(item)
        case .copyPlain:
            ClipboardWriter.writePlain(item.textContent ?? item.displayText)
        case .copyEditedText(let text):
            ClipboardWriter.writePlain(text)
        }
    }
}
