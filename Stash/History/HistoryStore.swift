//
//  HistoryStore.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation
import GRDB
import Observation

@MainActor
@Observable
final class HistoryStore {
    private(set) var items: [ClipboardItem] = []
    private(set) var loaded = false
    private let db: DatabaseQueue

    init(db: DatabaseQueue) {
        self.db = db
    }

    func loadAll() {
        guard let rows = try? db.read({ db in
            try HistoryDatabase.fetchAll(in: db)
        }) else { return }
        items = rows
        loaded = true
    }

    enum IngestResult: Equatable {
        case inserted(ClipboardItem)
        case duplicateMerged(ClipboardItem)
    }

    /// Inserts a new item, or merges a duplicate (bumps lastUsedAt, moves to top).
    @discardableResult
    func ingest(_ item: ClipboardItem) -> IngestResult? {
        let db = self.db
        var result: IngestResult?
        do {
            try db.write { db in
                if let existing = try HistoryDatabase.findByHash(item.contentHash, in: db) {
                    let now = item.lastUsedAt
                    try HistoryDatabase.touch(id: existing.id, at: now, in: db)
                    var merged = existing
                    merged.lastUsedAt = now
                    merged.useCount += 1
                    result = .duplicateMerged(merged)
                } else {
                    try HistoryDatabase.insert(item, in: db)
                    result = .inserted(item)
                }
            }
        } catch {
            NSLog("HistoryStore.ingest failed: \(error)")
            return nil
        }

        guard let result else { return nil }
        switch result {
        case .inserted(let newItem):
            items.insert(newItem, at: 0)
        case .duplicateMerged(let merged):
            if let idx = items.firstIndex(where: { $0.id == merged.id }) {
                items.remove(at: idx)
            }
            items.insert(merged, at: 0)
        }
        return result
    }

    func delete(id: String) {
        delete(ids: [id])
    }

    func delete(ids: Set<String>) {
        let list = Array(ids)
        guard !list.isEmpty else { return }
        do {
            try db.write { db in
                try HistoryDatabase.delete(ids: list, in: db)
            }
            for id in list {
                FileStorage.delete(id: id)
            }
        } catch {
            NSLog("HistoryStore.delete failed: \(error)")
        }
        items.removeAll { list.contains($0.id) }
    }

    func deleteAll() {
        do {
            try db.write { db in
                try HistoryDatabase.deleteAll(in: db)
            }
            FileStorage.clearAll()
        } catch {
            NSLog("HistoryStore.deleteAll failed: \(error)")
        }
        items.removeAll()
    }

    func togglePin(id: String) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let newValue = !item.isPinned
        do {
            try db.write { db in
                try HistoryDatabase.setPinned(newValue, id: id, in: db)
            }
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].isPinned = newValue
            }
        } catch {
            NSLog("HistoryStore.togglePin failed: \(error)")
        }
    }

    func markUsed(id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        let item = items[idx]
        do {
            try db.write { db in
                try HistoryDatabase.setUsedAt(id: id, date: now, useCount: item.useCount + 1, in: db)
            }
        } catch {
            NSLog("HistoryStore.markUsed failed: \(error)")
        }
        var updated = items[idx]
        updated.lastUsedAt = now
        updated.useCount += 1
        items.remove(at: idx)
        items.insert(updated, at: 0)
    }

    /// Replaces an item's text. The original is updated in place.
    @discardableResult
    func updateText(id: String, text: String) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return false }
        let old = items[idx]
        let newHash = DeduplicationService.textHash(text)
        let newType = ClipboardParser.detectType(forText: text)
        let db = self.db

        do {
            try db.write { db in
                // Collision with another item? Merge into it and drop this one.
                if let existing = try HistoryDatabase.findByHash(newHash, in: db), existing.id != id {
                    try HistoryDatabase.delete(ids: [id], in: db)
                    try HistoryDatabase.touch(id: existing.id, at: Date(), in: db)
                } else {
                    try HistoryDatabase.updateContent(id: id, text: text, rich: nil, type: newType, hash: newHash, in: db)
                }
            }
        } catch {
            NSLog("HistoryStore.updateText failed: \(error)")
            return false
        }

        if let existingIndex = items.firstIndex(where: { $0.contentHash == newHash && $0.id != id }) {
            items.remove(at: idx)
            var merged = items[existingIndex]
            merged.lastUsedAt = Date()
            merged.useCount += 1
            items.remove(at: existingIndex)
            items.insert(merged, at: 0)
        } else {
            var updated = items[idx]
            updated.textContent = text
            updated.richTextData = nil
            updated.type = newType
            updated.contentHash = newHash
            items[idx] = updated
        }
        return true
    }

    func setCollection(itemID: String, collectionID: String?) {
        do {
            try db.write { db in
                try HistoryDatabase.setCollection(itemID: itemID, collectionID: collectionID, in: db)
            }
            if let idx = items.firstIndex(where: { $0.id == itemID }) {
                items[idx].collectionID = collectionID
            }
        } catch {
            NSLog("HistoryStore.setCollection failed: \(error)")
        }
    }

    func recentItems(limit: Int) -> [ClipboardItem] {
        Array(items.prefix(limit))
    }

    /// Removes items from memory (used after retention sweeps).
    func removeFromMemory(ids: Set<String>) {
        items.removeAll { ids.contains($0.id) }
    }

    /// Re-syncs memory from the database (after bulk operations).
    func refresh() {
        loadAll()
    }
}
