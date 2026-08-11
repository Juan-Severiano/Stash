//
//  ClipboardItem.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation

struct ClipboardItem: Identifiable, Equatable, Sendable {
    var id: String
    var type: ItemType
    var textContent: String?
    var richTextData: Data?
    var filePath: String?
    var previewPath: String?
    var fileURLs: [String]
    var sourceApp: String?
    var sourceBundleID: String?
    var contentHash: String
    var createdAt: Date
    var lastUsedAt: Date
    var useCount: Int
    var isPinned: Bool
    var isSensitive: Bool
    var collectionID: String?

    var displayText: String {
        switch type {
        case .image, .screenshot:
            return textContent ?? "Image"
        case .file:
            if let first = fileURLs.first {
                return URL(fileURLWithPath: first).lastPathComponent
            }
            return "File"
        default:
            return textContent ?? ""
        }
    }

    var searchText: String {
        switch type {
        case .file: fileURLs.joined(separator: " ")
        case .image, .screenshot: textContent ?? ""
        default: textContent ?? ""
        }
    }

    func with(collectionID newValue: String?) -> ClipboardItem {
        var copy = self
        copy.collectionID = newValue
        return copy
    }
}
