//
//  FileStorage.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation

enum FileStorage {
    nonisolated static var rootDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stash", isDirectory: true)
    }

    nonisolated static var filesDirectory: URL {
        rootDirectory.appendingPathComponent("files", isDirectory: true)
    }

    nonisolated static var previewsDirectory: URL {
        rootDirectory.appendingPathComponent("previews", isDirectory: true)
    }

    nonisolated static var databaseURL: URL {
        rootDirectory.appendingPathComponent("stash.sqlite")
    }

    nonisolated static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: previewsDirectory, withIntermediateDirectories: true)
    }

    nonisolated static func fileURL(id: String) -> URL {
        filesDirectory.appendingPathComponent("\(id).png")
    }

    nonisolated static func previewURL(id: String) -> URL {
        previewsDirectory.appendingPathComponent("\(id).jpg")
    }

    @discardableResult
    nonisolated static func saveImage(_ data: Data, id: String) throws -> URL {
        try ensureDirectories()
        let url = fileURL(id: id)
        try data.write(to: url)
        return url
    }

    @discardableResult
    nonisolated static func savePreview(_ data: Data, id: String) throws -> URL {
        try ensureDirectories()
        let url = previewURL(id: id)
        try data.write(to: url)
        return url
    }

    nonisolated static func loadImageData(id: String) -> Data? {
        try? Data(contentsOf: fileURL(id: id))
    }

    nonisolated static func delete(id: String) {
        try? FileManager.default.removeItem(at: fileURL(id: id))
        try? FileManager.default.removeItem(at: previewURL(id: id))
    }

    nonisolated static func clearAll() {
        for url in [filesDirectory, previewsDirectory] {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { continue }
            for file in contents {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    nonisolated static func totalSize() -> Int64 {
        var total: Int64 = 0
        for url in [filesDirectory, previewsDirectory] {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for file in contents {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                total += Int64(size)
            }
        }
        return total
    }
}
