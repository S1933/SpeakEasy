import Foundation

enum SentenceNormalizer {
    static func normalize(_ text: String) -> String {
        var s = text.lowercased()
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")
        s = s.replacingOccurrences(of: "\u{2018}", with: "'")
        s = s.replacingOccurrences(of: "\u{02BC}", with: "'")
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespaces)
        let terminal = CharacterSet(charactersIn: ".?!,;:")
        s = s.trimmingCharacters(in: terminal)
        return s
    }

    static func tokenize(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return text.split(separator: " ").map(String.init)
    }
}
