//
//  StashPanel.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit

/// Borderless floating panel that can become key for text input.
final class StashPanel: NSPanel {
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        if let onResignKey {
            onResignKey()
        }
    }
}
