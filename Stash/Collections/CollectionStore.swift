//
//  CollectionStore.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation
import GRDB
import Observation

@MainActor
@Observable
final class CollectionStore {
    private(set) var collections: [CollectionRecord] = []
    private let db: DatabaseQueue

    init(db: DatabaseQueue) {
        self.db = db
    }

    func load() {
        collections = (try? db.read { db in
            try HistoryDatabase.fetchCollections(in: db)
        }) ?? []
    }

    func create(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let record = CollectionRecord(
            id: UUID().uuidString,
            name: trimmed,
            position: collections.count,
            createdAt: Date(),
            itemCount: 0
        )
        do {
            try db.write { db in
                try HistoryDatabase.insertCollection(record, in: db)
            }
        } catch {
            NSLog("CollectionStore.create failed: \(error)")
        }
        load()
    }

    func rename(id: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try db.write { db in
                try HistoryDatabase.renameCollection(id: id, name: trimmed, in: db)
            }
        } catch {
            NSLog("CollectionStore.rename failed: \(error)")
        }
        load()
    }

    func delete(id: String) {
        do {
            try db.write { db in
                try HistoryDatabase.deleteCollection(id: id, in: db)
            }
        } catch {
            NSLog("CollectionStore.delete failed: \(error)")
        }
        load()
        AppServices.shared.history.refresh()
    }

    func assign(itemID: String, to collectionID: String?) {
        AppServices.shared.history.setCollection(itemID: itemID, collectionID: collectionID)
        load()
    }
}
