//
//  ScreenshotWatcher.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit

/// Watches the macOS screenshot folder for new screenshots taken with ⌘⇧3/4/5.
@MainActor
final class ScreenshotWatcher {
    private let settings: SettingsStore
    private let store: HistoryStore
    private var timer: Timer?
    private var known: [String: Int64] = [:]
    private var pending: [String: (size: Int64, firstSeen: Date)] = [:]
    private var directory: URL?
    private var directoryFetchedAt: Date?
    private var recentlyCopiedHashes: [String: Date] = [:]

    init(settings: SettingsStore, store: HistoryStore) {
        self.settings = settings
        self.store = store
    }

    func start() {
        stop()
        known = [:]
        pending = [:]
        directory = nil
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scan()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        scan()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// True if this hash was placed on the pasteboard by the watcher recently.
    func wasRecentlyCopied(_ hash: String) -> Bool {
        let cutoff = Date().addingTimeInterval(-10)
        recentlyCopiedHashes = recentlyCopiedHashes.filter { $0.value > cutoff }
        return recentlyCopiedHashes[hash] != nil
    }

    // MARK: - Scanning

    private func scan() {
        let dir = resolveDirectory()
        guard let dir else { return }

        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        var current: [String: Int64] = [:]

        for url in files where isScreenshot(url) {
            let name = url.lastPathComponent
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
            current[name] = size

            if known[name] == size { continue }

            if let candidate = pending[name], candidate.size == size {
                pending.removeValue(forKey: name)
                known[name] = size
                handle(url)
            } else if let candidate = pending[name], Date().timeIntervalSince(candidate.firstSeen) > 20 {
                // File kept changing (still being written); give up on this name.
                pending.removeValue(forKey: name)
                known[name] = size
            } else {
                pending[name] = (size, Date())
            }
        }

        for name in known.keys where current[name] == nil {
            known[name] = nil
        }
        for name in pending.keys where current[name] == nil {
            pending[name] = nil
        }
    }

    private func isScreenshot(_ url: URL) -> Bool {
        guard url.lastPathComponent.hasPrefix("Screenshot ") else { return false }
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "heic", "tiff", "gif"].contains(ext)
    }

    private func handle(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let id = UUID().uuidString
        let now = Date()
        let hash = DeduplicationService.imageHash(data)

        Task.detached(priority: .utility) {
            let thumbnail = ImageOps.makeThumbnail(data: data)
            var filePath: String?
            var previewPath: String?
            do {
                filePath = try FileStorage.saveImage(data, id: id).path
                if let thumbnail {
                    previewPath = try FileStorage.savePreview(thumbnail, id: id).path
                }
            } catch {
                NSLog("Screenshot save failed: \(error)")
            }
            let item = ClipboardItem(
                id: id,
                type: .screenshot,
                textContent: url.lastPathComponent,
                richTextData: nil,
                filePath: filePath,
                previewPath: previewPath,
                fileURLs: [],
                sourceApp: "Screenshot",
                sourceBundleID: nil,
                contentHash: hash,
                createdAt: now,
                lastUsedAt: now,
                useCount: 1,
                isPinned: false,
                isSensitive: false,
                collectionID: nil
            )
            await MainActor.run {
                if self.settings.keepScreenshotsInHistory {
                    self.store.ingest(item)
                }
                if self.settings.copyScreenshotsToClipboard {
                    self.recentlyCopiedHashes[hash] = Date()
                    ClipboardWriter.writeImage(data: data)
                }
                if self.settings.deleteScreenshotFileAfterCapture {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    // MARK: - Directory resolution

    private func resolveDirectory() -> URL? {
        if let dir = directory, let fetchedAt = directoryFetchedAt, Date().timeIntervalSince(fetchedAt) < 300 {
            return dir
        }

        var resolved: URL?

        let custom = settings.screenshotLocation
        if !custom.isEmpty {
            let url = URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                resolved = url
            }
        }

        if resolved == nil, let location = defaultsScreenshotLocation() {
            let url = URL(fileURLWithPath: location, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                resolved = url
            }
        }

        if resolved == nil {
            resolved = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        }

        directory = resolved
        directoryFetchedAt = Date()
        return resolved
    }

    private func defaultsScreenshotLocation() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.screencapture", "location"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
