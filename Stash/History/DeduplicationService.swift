//
//  DeduplicationService.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import CryptoKit
import Foundation

enum DeduplicationService {
    nonisolated static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func textHash(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return sha256(Data(normalized.utf8))
    }

    nonisolated static func imageHash(_ data: Data) -> String {
        sha256(data)
    }

    nonisolated static func fileHash(_ paths: [String]) -> String {
        let sorted = paths.sorted().joined(separator: "\n")
        return sha256(Data(sorted.utf8))
    }
}
