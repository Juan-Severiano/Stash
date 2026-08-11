//
//  ClipboardPanelController.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import SwiftUI

@MainActor
final class ClipboardPanelController {
    static let panelSize = NSSize(width: 580, height: 480)

    private let panel: StashPanel
    private var hostingView: NSHostingView<AnyView>?
    private var escapeMonitor: Any?
    private var isHidingProgrammatically = false
    var onClose: (() -> Void)?

    var isVisible: Bool { panel.isVisible }

    init() {
        panel = StashPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false
        panel.onResignKey = { [weak self] in
            self?.closeIfNeeded()
        }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, event.keyCode == 53 else { return event }
            self.hide()
            return nil
        }
    }

    func setContentView<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(origin: .zero, size: Self.panelSize)
        hosting.autoresizingMask = [.width, .height]
        hostingView = hosting
        panel.contentView = hosting
    }

    func show() {
        AppServices.shared.focusManager.rememberCurrent()

        if panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            hostingView?.needsDisplay = true
            return
        }

        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
                ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - Self.panelSize.width / 2,
            y: visible.midY - Self.panelSize.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: Self.panelSize), display: false)
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide(restoreFocus: Bool = true) {
        isHidingProgrammatically = true
        panel.orderOut(nil)
        isHidingProgrammatically = false
        if restoreFocus {
            onClose?()
        }
    }

    func closeIfNeeded() {
        guard !isHidingProgrammatically, panel.isVisible else { return }
        panel.orderOut(nil)
        onClose?()
    }
}
