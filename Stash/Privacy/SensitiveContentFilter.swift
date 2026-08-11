//
//  SensitiveContentFilter.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation

enum SensitiveContentFilter {
    struct Classification: Equatable {
        var isSensitive: Bool
        var isOTP: Bool
    }

    static func classify(text: String, settings: SettingsStore) -> Classification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if settings.ignoreOTPCodes, isOTPCode(trimmed) {
            return Classification(isSensitive: true, isOTP: true)
        }

        if settings.ignorePasswords, isPasswordLike(trimmed) {
            return Classification(isSensitive: true, isOTP: false)
        }

        return Classification(isSensitive: false, isOTP: false)
    }

    static func isOTPCode(_ text: String) -> Bool {
        text.count == 6 && text.allSatisfy(\.isNumber)
    }

    /// Heuristic for generated credentials: one token, no spaces, 12+ chars, mixed classes.
    static func isPasswordLike(_ text: String) -> Bool {
        guard !text.contains(" "), !text.contains("\n") else { return false }
        guard text.count >= 12, text.count <= 64 else { return false }
        let hasUpper = text.contains { $0.isUppercase && $0.isLetter }
        let hasLower = text.contains { $0.isLowercase && $0.isLetter }
        let hasDigit = text.contains(where: \.isNumber)
        return hasUpper && hasLower && hasDigit
    }
}
