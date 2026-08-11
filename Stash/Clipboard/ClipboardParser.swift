//
//  ClipboardParser.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation

enum ClipboardParser {
    /// Detects the semantic type of a text snippet.
    static func detectType(forText rawText: String) -> ItemType {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .text }

        if isLink(text) { return .link }
        if isEmail(text) { return .email }
        if isColor(text) { return .color }
        if isPhone(text) { return .phone }
        if isCode(text) { return .code }
        return .text
    }

    static func isLink(_ text: String) -> Bool {
        guard let url = URL(string: text) else { return false }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        return url.host?.contains(".") == true
    }

    static func isEmail(_ text: String) -> Bool {
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return range(of: pattern, in: text) != nil
    }

    static func isColor(_ text: String) -> Bool {
        let hex = "^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"
        let rgb = "^rgb(a)?\\([\\s0-9.,%]+\\)$"
        return range(of: hex, in: text) != nil || range(of: rgb, in: text) != nil
    }

    static func isPhone(_ text: String) -> Bool {
        let pattern = "^\\+?[0-9()\\s.\\-]{7,25}$"
        let digitCount = text.filter(\.isNumber).count
        return digitCount >= 8 && digitCount <= 15 && range(of: pattern, in: text) != nil
    }

    static func isCode(_ text: String) -> Bool {
        let commandPrefixes = [
            "npm", "npx", "yarn", "pnpm", "brew", "git", "ssh", "docker", "kubectl",
            "gh", "curl", "wget", "sudo", "python", "pip", "pip3", "poetry", "go",
            "cargo", "rustup", "make", "gem", "bundle", "rails", "node", "sqlite3",
            "psql", "mysql", "redis-cli", "terraform", "aws", "gcloud", "gitlab",
            "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP",
        ]

        if !text.contains("\n") {
            let firstWord = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init)
            if let firstWord, commandPrefixes.contains(firstWord) { return true }
            return false
        }

        let codeMarkers = ["{", "}", ";", "=>", "func ", "def ", "class ", "import ",
                           "#include", "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE",
                           "if (", "for (", "while (", "try {", "function ", "var ", "let ", "const "]
        return codeMarkers.contains { text.contains($0) }
    }

    private static func range(of pattern: String, in text: String) -> NSRange? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        return regex.rangeOfFirstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }
}
