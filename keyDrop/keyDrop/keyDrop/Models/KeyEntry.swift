//
//  KeyEntry.swift
//  keyDrop
//

import Foundation

struct KeyEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var label: String
    let createdAt: Date
    var keyPreview: String

    var keychainAccount: String { id.uuidString }

    static func makePreview(from key: String, prefixCount: Int = 7, suffixCount: Int = 3) -> String {
        let stripped = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.count > prefixCount + suffixCount else {
            return String(repeating: "*", count: max(stripped.count, 4))
        }
        let head = String(stripped.prefix(prefixCount))
        let tail = String(stripped.suffix(suffixCount))
        let starCount = max(8, min(20, stripped.count - prefixCount - suffixCount))
        return head + String(repeating: "*", count: starCount) + tail
    }
}
