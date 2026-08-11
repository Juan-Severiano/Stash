//
//  HotkeyRecorderView.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import SwiftUI

/// A clickable field that captures the next key combination pressed.
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var value: String
    var onChange: () -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onKey = { keyCode, modifiers in
            value = HotkeyCodec.encode(keyCode: keyCode, modifiers: modifiers)
            onChange()
        }
        view.displayString = HotkeyCodec.display(value)
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.displayString = HotkeyCodec.display(value)
    }
}

final class HotkeyRecorderNSView: NSView {
    var onKey: ((Int, NSEvent.ModifierFlags) -> Void)?
    var displayString = "Press keys…" {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 28) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode != 53 else { return } // Escape cancels
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard HotkeyCodec.hasShortcutModifier(modifiers) else {
            NSSound.beep()
            return
        }
        onKey?(Int(event.keyCode), modifiers)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let isFirstResponder = window?.firstResponder === self
        let corner: CGFloat = 6
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: corner, yRadius: corner)
        (isFirstResponder ? NSColor.controlAccentColor.withAlphaComponent(0.25) : NSColor.quaternaryLabelColor.withAlphaComponent(0.25)).setFill()
        path.fill()
        (isFirstResponder ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let text = isFirstResponder ? "Press keys…" : displayString
        let size = text.size(withAttributes: attributes)
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        text.draw(in: rect, withAttributes: attributes)
    }
}
