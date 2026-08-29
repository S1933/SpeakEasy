import Foundation

enum ReadingKind: String, Codable, Sendable, Hashable {
    case conversation
    case story
}

struct ReadingLine: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    /// nil pour un récit ; nom du personnage pour un dialogue.
    let speaker: String?
    let text: String
}

struct ReadingText: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let kind: ReadingKind
    let title: String
    let difficulty: Int          // 1...4
    let lines: [ReadingLine]

    var wordCount: Int {
        lines.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    /// Les personnages dans l'ordre d'apparition. Vide pour un récit.
    var speakers: [String] {
        var seen: [String] = []
        for line in lines {
            if let s = line.speaker, !seen.contains(s) { seen.append(s) }
        }
        return seen
    }
}