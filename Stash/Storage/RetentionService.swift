//
//  RetentionService.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation
import GRDB

@MainActor
final class RetentionService {
    private let db: DatabaseQueue
    private let store: HistoryStore
    private var timer: Timer?

    init(db: DatabaseQueue, store: HistoryStore) {
        self.db = db
        self.store = store
    }

    func schedule() {
        sweep()
        let timer = Timer(timeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sweep()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func sweep() {
        let settings = AppServices.shared.settings
        let now = Date()
        var deleted: Set<String> = []

        do {
            try db.write { db in
                if settings.keepTextHistoryDays > 0 {
                    let cutoff = now.addingTimeInterval(-Double(settings.keepTextHistoryDays) * 86_400)
                    let imageTypes: [ItemType] = [.image, .screenshot]
                    let ids = try HistoryDatabase.deleteWhere(
                        createdBefore: cutoff,
                        types: ItemType.allCases.filter { !imageTypes.contains($0) },
                        excludePinned: true,
                        in: db
                    )
                    deleted.formUnion(ids)
                }

                if settings.keepImagesDays > 0 {
                    let cutoff = now.addingTimeInterval(-Double(settings.keepImagesDays) * 86_400)
                    let ids = try HistoryDatabase.deleteWhere(
                        createdBefore: cutoff,
                        types: [.image, .screenshot],
                        excludePinned: true,
                        in: db
                    )
                    deleted.formUnion(ids)
                }

                if settings.autoDeleteSensitiveItems {
                    let ids = try HistoryDatabase.deleteSensitive(otpLifetime: settings.otpLifetimeSeconds, in: db)
                    deleted.formUnion(ids)
                }

                if settings.maxHistorySize > 0 {
                    let count = try HistoryDatabase.count(in: db)
                    if count > settings.maxHistorySize {
                        let overflow = count - settings.maxHistorySize
                        let oldest = try HistoryDatabase.oldestNonPinned(limit: overflow, in: db)
                        try HistoryDatabase.delete(ids: oldest.map(\.id), in: db)
                        deleted.formUnion(oldest.map(\.id))
                    }
                }

                if settings.maxStorageMB > 0 {
                    let budget = Int64(settings.maxStorageMB) * 1024 * 1024
                    var size = FileStorage.totalSize()
                    var iterations = 0
                    while size > budget, iterations < 500 {
                        iterations += 1
                        guard let oldest = try HistoryDatabase.oldestNonPinned(limit: 1, in: db).first else { break }
                        try HistoryDatabase.delete(ids: [oldest.id], in: db)
                        FileStorage.delete(id: oldest.id)
                        deleted.insert(oldest.id)
                        size = FileStorage.totalSize()
                    }
                }
            }
        } catch {
            NSLog("RetentionService.sweep failed: \(error)")
        }

        for id in deleted {
            FileStorage.delete(id: id)
        }
        if !deleted.isEmpty {
            store.removeFromMemory(ids: deleted)
        }
    }
}
