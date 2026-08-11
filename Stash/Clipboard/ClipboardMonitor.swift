//
//  ClipboardMonitor.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit

@MainActor
final class ClipboardMonitor {
    private let settings: SettingsStore
    private let store: HistoryStore
    private var timer: Timer?
    private var lastChangeCount: Int = -1

    init(settings: SettingsStore, store: HistoryStore) {
        self.settings = settings
        self.store = store
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    func checkPasteboard() {
        let pb = NSPasteboard.general
        let changeCount = pb.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard settings.clipboardEnabled, !settings.isPaused else { return }

        guard let payload = readPayload(from: pb), !payload.isEmpty else { return }

        let frontmost = NSWorkspace.shared.frontmostApplication
        if settings.ignoresApp(bundleID: frontmost?.bundleIdentifier) { return }

        switch payload {
        case .text(let text, let rich):
            handleText(text, rich: rich, source: frontmost)
        case .image(let data, let isPNG):
            handleImage(data, isPNG: isPNG, source: frontmost)
        case .files(let paths):
            handleFiles(paths, source: frontmost)
        }
    }

    private func readPayload(from pb: NSPasteboard) -> PasteboardPayload? {
        if let urls = pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            return .files(urls.map(\.path))
        }
        if let png = pb.data(forType: .png) {
            return .image(png, isPNG: true)
        }
        if let tiff = pb.data(forType: .tiff) {
            return .image(tiff, isPNG: false)
        }
        let rich = pb.data(forType: .rtf)
        let text = pb.string(forType: .string)
        if let text, !text.isEmpty {
            return .text(text, rich)
        }
        return nil
    }

    // MARK: - Handlers

    private func handleText(_ text: String, rich: Data?, source: NSRunningApplication?) {
        let hash = DeduplicationService.textHash(text)
        let classification = SensitiveContentFilter.classify(text: text, settings: settings)
        let type = ClipboardParser.detectType(forText: text)
        let now = Date()
        let item = ClipboardItem(
            id: UUID().uuidString,
            type: type,
            textContent: text,
            richTextData: rich,
            filePath: nil,
            previewPath: nil,
            fileURLs: [],
            sourceApp: source?.localizedName,
            sourceBundleID: source?.bundleIdentifier,
            contentHash: hash,
            createdAt: now,
            lastUsedAt: now,
            useCount: 1,
            isPinned: false,
            isSensitive: classification.isSensitive,
            collectionID: nil
        )
        store.ingest(item)
    }

    private func handleImage(_ data: Data, isPNG: Bool, source: NSRunningApplication?) {
        let id = UUID().uuidString
        let now = Date()
        let hash = DeduplicationService.imageHash(data)

        Task.detached(priority: .utility) {
            let pngData = isPNG ? data : (ImageOps.convertToPNG(data) ?? data)
            let thumbnail = ImageOps.makeThumbnail(data: pngData)
            var filePath: String?
            var previewPath: String?
            do {
                filePath = try FileStorage.saveImage(pngData, id: id).path
                if let thumbnail {
                    previewPath = try FileStorage.savePreview(thumbnail, id: id).path
                }
            } catch {
                NSLog("Image save failed: \(error)")
            }
            let item = ClipboardItem(
                id: id,
                type: .image,
                textContent: "Image",
                richTextData: nil,
                filePath: filePath,
                previewPath: previewPath,
                fileURLs: [],
                sourceApp: source?.localizedName,
                sourceBundleID: source?.bundleIdentifier,
                contentHash: hash,
                createdAt: now,
                lastUsedAt: now,
                useCount: 1,
                isPinned: false,
                isSensitive: false,
                collectionID: nil
            )
            await MainActor.run {
                self.store.ingest(item)
            }
        }
    }

    private func handleFiles(_ paths: [String], source: NSRunningApplication?) {
        let hash = DeduplicationService.fileHash(paths)
        let now = Date()
        let names = paths.map { URL(fileURLWithPath: $0).lastPathComponent }
        let item = ClipboardItem(
            id: UUID().uuidString,
            type: .file,
            textContent: names.joined(separator: ", "),
            richTextData: nil,
            filePath: nil,
            previewPath: nil,
            fileURLs: paths,
            sourceApp: source?.localizedName,
            sourceBundleID: source?.bundleIdentifier,
            contentHash: hash,
            createdAt: now,
            lastUsedAt: now,
            useCount: 1,
            isPinned: false,
            isSensitive: false,
            collectionID: nil
        )
        store.ingest(item)
    }
}

enum PasteboardPayload {
    case text(String, Data?)
    case image(Data, isPNG: Bool)
    case files([String])

    var isEmpty: Bool {
        switch self {
        case .text(let text, _): text.isEmpty
        case .image(let data, _): data.isEmpty
        case .files(let paths): paths.isEmpty
        }
    }
}
