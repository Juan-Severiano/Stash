//
//  ItemDetailSheet.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import QuickLookUI
import SwiftUI

/// Space-bar preview; for text items it doubles as an edit sheet.
struct ItemDetailSheet: View {
    let item: ClipboardItem
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isEditing = false

    init(item: ClipboardItem) {
        self.item = item
        _text = State(initialValue: item.textContent ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if item.type.isImageLike {
                if let path = item.filePath {
                    QuickLookPreview(url: URL(fileURLWithPath: path))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    placeholder
                }
            } else {
                TextEditor(text: $text)
                    .font(item.type == .code ? .system(size: 12, design: .monospaced) : .system(size: 12))
                    .scrollContentBackground(.hidden)
                    .disabled(!isEditing)
                    .padding(8)
            }

            footer
        }
        .frame(width: 520, height: 420)
        .background(.background)
    }

    private var header: some View {
        HStack {
            Image(systemName: item.type.icon)
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(.quaternary.opacity(0.6), in: Circle())
            Text(item.displayText)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Text(item.type.displayName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.5), in: Capsule())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var placeholder: some View {
        VStack {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Image data unavailable")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if !item.type.isImageLike {
                Button(isEditing ? "Done Editing" : "Edit") {
                    isEditing.toggle()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            Button("Copy") {
                ClipboardWriter.writePlain(text)
                dismiss()
            }
            .buttonStyle(.bordered)
            Button("Paste") {
                AppServices.shared.paste.perform(text: text, mode: .pasteEditedText(text))
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

/// Sheet showing OCR'd text from an image.
struct OCRResultSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(.tint)
                Text("Recognized Text")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            TextEditor(text: .constant(text))
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(8)

            HStack {
                Spacer()
            Button("Copy") {
                ClipboardWriter.writePlain(text)
                dismiss()
            }
            .buttonStyle(.bordered)
            Button("Paste") {
                AppServices.shared.paste.perform(text: text, mode: .pasteEditedText(text))
                dismiss()
            }
            .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .frame(width: 520, height: 420)
        .background(.background)
    }
}

struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView(frame: .zero)!
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
    }
}
