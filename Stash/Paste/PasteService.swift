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

    /// Copies a history item to the system pasteboard and pastes it into
    /// whichever app was frontmost before the panel opened.
    func perform(_ item: ClipboardItem, mode: Mode) {
        store.markUsed(id: item.id)
        apply(item: item, mode: mode)
        AppServices.shared.panel.hide(restoreFocus: true)
        if settings.playSounds {
            NSSound(named: "Pop")?.play()
        }
        pasteAfterFocusRestored()
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
        pasteAfterFocusRestored()
    }

    /// The panel's window has to resign key and the target app has to become
    /// active before a synthetic ⌘V would land in the right place.
    private func pasteAfterFocusRestored() {
        guard settings.autoPaste else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            PasteSimulator.simulatePaste()
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
