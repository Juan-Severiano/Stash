//
//  Database.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation
import GRDB

enum StashDatabase {
    nonisolated static func open() throws -> DatabaseQueue {
        try FileStorage.ensureDirectories()
        let dbQueue = try DatabaseQueue(path: FileStorage.databaseURL.path)
        try migrate(dbQueue)
        return dbQueue
    }

    nonisolated static func migrate(_ dbQueue: DatabaseQueue) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS items (
                    id TEXT PRIMARY KEY,
                    type TEXT NOT NULL,
                    text_content TEXT,
                    rich_text_data BLOB,
                    file_path TEXT,
                    preview_path TEXT,
                    file_urls TEXT,
                    source_app TEXT,
                    source_bundle_id TEXT,
                    content_hash TEXT NOT NULL UNIQUE,
                    created_at REAL NOT NULL,
                    last_used_at REAL NOT NULL,
                    use_count INTEGER NOT NULL DEFAULT 1,
                    is_pinned INTEGER NOT NULL DEFAULT 0,
                    is_sensitive INTEGER NOT NULL DEFAULT 0,
                    collection_id TEXT
                )
                """)
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_items_last_used ON items(last_used_at DESC)
                """)
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_items_type ON items(type)
                """)
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_items_pinned ON items(is_pinned)
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS collections (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    created_at REAL NOT NULL
                )
                """)
        }
    }
}

enum HistoryDatabase {
    // MARK: - Item mapping

    nonisolated static func item(from row: Row) -> ClipboardItem {
        let id: String = row["id"]
        let typeRaw: String = row["type"]
        let createdAt: Double = row["created_at"]
        let lastUsedAt: Double = row["last_used_at"]
        let useCount: Int = row["use_count"]
        let isPinned: Bool = row["is_pinned"]
        let isSensitive: Bool = row["is_sensitive"]
        let fileURLsRaw: String? = row["file_urls"]
        let fileURLs: [String] = fileURLsRaw
            .flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? []

        return ClipboardItem(
            id: id,
            type: ItemType(rawValue: typeRaw) ?? .text,
            textContent: row["text_content"],
            richTextData: row["rich_text_data"],
            filePath: row["file_path"],
            previewPath: row["preview_path"],
            fileURLs: fileURLs,
            sourceApp: row["source_app"],
            sourceBundleID: row["source_bundle_id"],
            contentHash: row["content_hash"],
            createdAt: Date(timeIntervalSince1970: createdAt),
            lastUsedAt: Date(timeIntervalSince1970: lastUsedAt),
            useCount: useCount,
            isPinned: isPinned,
            isSensitive: isSensitive,
            collectionID: row["collection_id"]
        )
    }

    // MARK: - CRUD

    nonisolated static func insert(_ item: ClipboardItem, in db: GRDB.Database) throws {
        let fileURLs = try JSONEncoder().encode(item.fileURLs).base64EncodedString()
        try db.execute(
            sql: """
                INSERT INTO items (id, type, text_content, rich_text_data, file_path, preview_path,
                                   file_urls, source_app, source_bundle_id, content_hash,
                                   created_at, last_used_at, use_count, is_pinned, is_sensitive, collection_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                item.id,
                item.type.rawValue,
                item.textContent,
                item.richTextData,
                item.filePath,
                item.previewPath,
                fileURLs,
                item.sourceApp,
                item.sourceBundleID,
                item.contentHash,
                item.createdAt.timeIntervalSince1970,
                item.lastUsedAt.timeIntervalSince1970,
                item.useCount,
                item.isPinned,
                item.isSensitive,
                item.collectionID,
            ])
    }

    nonisolated static func findByHash(_ hash: String, in db: GRDB.Database) throws -> ClipboardItem? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM items WHERE content_hash = ?", arguments: [hash]) else {
            return nil
        }
        return item(from: row)
    }

    nonisolated static func touch(id: String, at date: Date, in db: GRDB.Database) throws {
        try db.execute(
            sql: "UPDATE items SET last_used_at = ?, use_count = use_count + 1 WHERE id = ?",
            arguments: [date.timeIntervalSince1970, id])
    }

    nonisolated static func setUsedAt(id: String, date: Date, useCount: Int, in db: GRDB.Database) throws {
        try db.execute(
            sql: "UPDATE items SET last_used_at = ?, use_count = ? WHERE id = ?",
            arguments: [date.timeIntervalSince1970, useCount, id])
    }

    nonisolated static func fetchAll(in db: GRDB.Database) throws -> [ClipboardItem] {
        try Row.fetchAll(db, sql: "SELECT * FROM items ORDER BY last_used_at DESC").map(item(from:))
    }

    nonisolated static func fetchRecent(limit: Int, in db: GRDB.Database) throws -> [ClipboardItem] {
        try Row.fetchAll(db, sql: "SELECT * FROM items ORDER BY last_used_at DESC LIMIT ?", arguments: [limit])
            .map(item(from:))
    }

    nonisolated static func delete(ids: [String], in db: GRDB.Database) throws {
        guard !ids.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        try db.execute(sql: "DELETE FROM items WHERE id IN (\(placeholders))", arguments: StatementArguments(ids))
    }

    nonisolated static func deleteAll(in db: GRDB.Database) throws {
        try db.execute(sql: "DELETE FROM items")
    }

    nonisolated static func setPinned(_ pinned: Bool, id: String, in db: GRDB.Database) throws {
        try db.execute(sql: "UPDATE items SET is_pinned = ? WHERE id = ?", arguments: [pinned, id])
    }

    nonisolated static func updateContent(id: String, text: String?, rich: Data?, type: ItemType, hash: String, in db: GRDB.Database) throws {
        try db.execute(
            sql: "UPDATE items SET text_content = ?, rich_text_data = ?, type = ?, content_hash = ? WHERE id = ?",
            arguments: [text, rich, type.rawValue, hash, id])
    }

    nonisolated static func setCollection(itemID: String, collectionID: String?, in db: GRDB.Database) throws {
        try db.execute(sql: "UPDATE items SET collection_id = ? WHERE id = ?", arguments: [collectionID, itemID])
    }

    nonisolated static func count(in db: GRDB.Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items") ?? 0
    }

    nonisolated static func oldestNonPinned(limit: Int, in db: GRDB.Database) throws -> [ClipboardItem] {
        try Row.fetchAll(
            db,
            sql: "SELECT * FROM items WHERE is_pinned = 0 ORDER BY last_used_at ASC LIMIT ?",
            arguments: [limit])
            .map(item(from:))
    }

    /// Deletes matching rows and returns their ids.
    nonisolated static func deleteWhere(
        createdBefore: Date,
        types: [ItemType]?,
        excludePinned: Bool,
        in db: GRDB.Database
    ) throws -> [String] {
        let cutoff = createdBefore.timeIntervalSince1970
        var sql = "SELECT id FROM items WHERE created_at < ?"
        var args: [DatabaseValueConvertible] = [cutoff]
        if let types, !types.isEmpty {
            let placeholders = Array(repeating: "?", count: types.count).joined(separator: ",")
            sql += " AND type IN (\(placeholders))"
            args += types.map(\.rawValue)
        }
        if excludePinned {
            sql += " AND is_pinned = 0"
        }
        let ids = try String.fetchAll(db, sql: sql, arguments: StatementArguments(args))
        if !ids.isEmpty {
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            try db.execute(sql: "DELETE FROM items WHERE id IN (\(placeholders))", arguments: StatementArguments(ids))
        }
        return ids
    }

    /// Deletes sensitive items (is_sensitive = 1). OTP-like items expire after `otpLifetime`, others after 24h.
    nonisolated static func deleteSensitive(otpLifetime: Int, in db: GRDB.Database) throws -> [String] {
        let now = Date().timeIntervalSince1970
        let otpCutoff = now - Double(max(otpLifetime, 1))
        let sensitiveCutoff = now - 86_400
        let sql = """
            SELECT id FROM items WHERE is_sensitive = 1 AND (
                (length(text_content) = 6 AND text_content GLOB '[0-9][0-9][0-9][0-9][0-9][0-9]' AND last_used_at < ?)
                OR last_used_at < ?
            )
            """
        let ids = try String.fetchAll(db, sql: sql, arguments: [otpCutoff, sensitiveCutoff])
        if !ids.isEmpty {
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            try db.execute(sql: "DELETE FROM items WHERE id IN (\(placeholders))", arguments: StatementArguments(ids))
        }
        return ids
    }

    // MARK: - Collections

    nonisolated static func fetchCollections(in db: GRDB.Database) throws -> [CollectionRecord] {
        try Row.fetchAll(db, sql: """
            SELECT c.*, (SELECT COUNT(*) FROM items i WHERE i.collection_id = c.id) AS item_count
            FROM collections c ORDER BY c.position, c.created_at
            """)
            .map { row in
                let id: String = row["id"]
                let name: String = row["name"]
                let position: Int = row["position"]
                let createdAt: Double = row["created_at"]
                let itemCount: Int = row["item_count"]
                return CollectionRecord(
                    id: id,
                    name: name,
                    position: position,
                    createdAt: Date(timeIntervalSince1970: createdAt),
                    itemCount: itemCount
                )
            }
    }

    nonisolated static func insertCollection(_ collection: CollectionRecord, in db: GRDB.Database) throws {
        try db.execute(
            sql: "INSERT INTO collections (id, name, position, created_at) VALUES (?, ?, ?, ?)",
            arguments: [
                collection.id,
                collection.name,
                collection.position,
                collection.createdAt.timeIntervalSince1970,
            ])
    }

    nonisolated static func renameCollection(id: String, name: String, in db: GRDB.Database) throws {
        try db.execute(sql: "UPDATE collections SET name = ? WHERE id = ?", arguments: [name, id])
    }

    nonisolated static func deleteCollection(id: String, in db: GRDB.Database) throws {
        try db.execute(sql: "DELETE FROM collections WHERE id = ?", arguments: [id])
        try db.execute(sql: "UPDATE items SET collection_id = NULL WHERE collection_id = ?", arguments: [id])
    }
}

struct CollectionRecord: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var position: Int
    var createdAt: Date
    var itemCount: Int
}
