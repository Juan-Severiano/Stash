//
//  QuickActions.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Quick actions

enum QuickAction: String, Identifiable, CaseIterable {
    case paste, copy, pastePlain, copyText, pin, unpin, open, copyMarkdown,
         sendEmail, save, ocr, compress, edit, revealInFinder, addToCollection, delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paste: "Paste"
        case .copy: "Copy"
        case .pastePlain: "Paste as Plain Text"
        case .copyText: "Copy Text"
        case .pin: "Pin"
        case .unpin: "Unpin"
        case .open: "Open"
        case .copyMarkdown: "Copy as Markdown"
        case .sendEmail: "Send Email"
        case .save: "Save…"
        case .ocr: "OCR Text"
        case .compress: "Compress"
        case .edit: "Edit"
        case .revealInFinder: "Reveal in Finder"
        case .addToCollection: "Add to Collection…"
        case .delete: "Delete"
        }
    }

    var icon: String {
        switch self {
        case .paste: "doc.on.clipboard"
        case .copy: "doc.on.doc"
        case .pastePlain: "doc.plaintext"
        case .copyText: "textformat"
        case .pin: "pin"
        case .unpin: "pin.slash"
        case .open: "arrow.up.right.square"
        case .copyMarkdown: "text.cursor"
        case .sendEmail: "paperplane"
        case .save: "square.and.arrow.down"
        case .ocr: "text.viewfinder"
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .edit: "pencil"
        case .revealInFinder: "folder"
        case .addToCollection: "folder.badge.plus"
        case .delete: "trash"
        }
    }
}

struct QuickActionsMenu: View {
    let item: ClipboardItem
    var onEdit: (ClipboardItem) -> Void
    var onOCRResult: (String) -> Void
    private var services: AppServices { AppServices.shared }
    @State private var showCollectionPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(actions) { action in
                Button {
                    perform(action)
                } label: {
                    Label(action.title, systemImage: action.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 220)
        .popover(isPresented: $showCollectionPicker, arrowEdge: .trailing) {
            CollectionPicker(item: item)
        }
    }

    private var actions: [QuickAction] {
        var base: [QuickAction]
        switch item.type {
        case .link:
            base = [.paste, .copy, .open, .copyMarkdown]
        case .email:
            base = [.paste, .copy, .sendEmail]
        case .image, .screenshot:
            base = [.paste, .copy, .copyText, .save, .ocr, .compress]
        case .file:
            base = [.paste, .copy, .revealInFinder]
        case .code:
            base = [.paste, .copy, .pastePlain]
        case .text, .phone, .color:
            base = [.paste, .copy, .edit]
        }
        base.append(item.isPinned ? .unpin : .pin)
        base.append(.addToCollection)
        base.append(.delete)
        return base
    }

    private func perform(_ action: QuickAction) {
        let services = services
        switch action {
        case .paste:
            services.paste.perform(item, mode: .paste)
        case .copy:
            services.paste.perform(item, mode: .copy)
        case .pastePlain:
            services.paste.perform(item, mode: .pastePlain)
        case .copyText:
            if let text = item.textContent {
                ClipboardWriter.writePlain(text)
            }
        case .pin, .unpin:
            services.history.togglePin(id: item.id)
        case .open:
            if let url = URL(string: item.textContent ?? "") {
                NSWorkspace.shared.open(url)
            }
        case .copyMarkdown:
            if let text = item.textContent, let url = URL(string: text), let host = url.host {
                ClipboardWriter.writePlain("[\(host)](\(text))")
            }
        case .sendEmail:
            if let text = item.textContent,
               let url = URL(string: "mailto:\(text)") {
                NSWorkspace.shared.open(url)
            }
        case .save:
            saveImage()
        case .ocr:
            ocr()
        case .compress:
            compress()
        case .edit:
            onEdit(item)
        case .revealInFinder:
            NSWorkspace.shared.activateFileViewerSelecting(item.fileURLs.map { URL(fileURLWithPath: $0) })
        case .addToCollection:
            showCollectionPicker = true
        case .delete:
            services.history.delete(id: item.id)
        }
    }

    private func saveImage() {
        guard let data = FileStorage.loadImageData(id: item.id) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = item.type == .screenshot
            ? (item.textContent ?? "screenshot.png")
            : "image.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private func ocr() {
        guard let data = FileStorage.loadImageData(id: item.id) else { return }
        Task {
            guard let text = await ImageOps.ocrText(data: data) else { return }
            ClipboardWriter.writePlain(text)
            onOCRResult(text)
        }
    }

    private func compress() {
        guard let data = FileStorage.loadImageData(id: item.id) else { return }
        Task.detached(priority: .utility) {
            guard let compressed = ImageOps.compressed(data: data) else { return }
            let id = UUID().uuidString
            let now = Date()
            var filePath: String?
            var previewPath: String?
            do {
                filePath = try FileStorage.saveImage(compressed, id: id).path
                if let thumb = ImageOps.makeThumbnail(data: compressed) {
                    previewPath = try FileStorage.savePreview(thumb, id: id).path
                }
            } catch {
                NSLog("Compress save failed: \(error)")
            }
            let item = ClipboardItem(
                id: id,
                type: .image,
                textContent: "Compressed image",
                richTextData: nil,
                filePath: filePath,
                previewPath: previewPath,
                fileURLs: [],
                sourceApp: "Stash",
                sourceBundleID: nil,
                contentHash: DeduplicationService.imageHash(compressed),
                createdAt: now,
                lastUsedAt: now,
                useCount: 1,
                isPinned: false,
                isSensitive: false,
                collectionID: nil
            )
            await MainActor.run {
                AppServices.shared.history.ingest(item)
                AppServices.shared.paste.perform(item, mode: .copy)
            }
        }
    }
}

// MARK: - Collection picker

struct CollectionPicker: View {
    let item: ClipboardItem
    private var services: AppServices { AppServices.shared }
    @State private var newCollectionName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(services.collections.collections) { collection in
                Button {
                    services.collections.assign(itemID: item.id, to: collection.id)
                } label: {
                    HStack {
                        Image(systemName: item.collectionID == collection.id ? "checkmark.circle.fill" : "circle")
                        Text(collection.name)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            Divider()
            HStack {
                TextField("New collection", text: $newCollectionName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(createCollection)
                Button("Add", action: createCollection)
            }
        }
        .padding(8)
        .frame(width: 200)
    }

    private func createCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        services.collections.create(name: name)
        if let collection = services.collections.collections.last {
            services.collections.assign(itemID: item.id, to: collection.id)
        }
        newCollectionName = ""
    }
}
