#!/usr/bin/env swift
import Foundation

// Validation du corpus avant enrichissement (S4.6).
// Usage : swift Scripts/validate_corpus.swift

let url = URL(fileURLWithPath: "SpeakEasy/Data/sentences.json")
struct S: Codable {
    let id: Int
    let category: String
    let french: String
    let english: String
    let difficulty: Int
    let keywords: [String]
    let acceptedVariants: [String]?
    let focusPhonemes: [String]?
}

let data = try Data(contentsOf: url)
let all = try JSONDecoder().decode([S].self, from: data)

var errors: [String] = []

// Unicité des ids
let dupes = Dictionary(grouping: all, by: \.id).filter { $1.count > 1 }
if !dupes.isEmpty { errors.append("Ids dupliqués: \(dupes.keys.sorted())") }

// Unicité des phrases anglaises
let dupeText = Dictionary(grouping: all, by: { $0.english.lowercased() }).filter { $1.count > 1 }
if !dupeText.isEmpty { errors.append("Phrases dupliquées: \(dupeText.keys.sorted().prefix(5))") }

for s in all {
    let words = s.english.split(separator: " ").count
    let expected: ClosedRange<Int> = switch s.difficulty {
        case 1: 2...6; case 2: 5...10; case 3: 9...15; default: 14...25
    }
    if !expected.contains(words) {
        errors.append("#\(s.id) diff=\(s.difficulty) mais \(words) mots: \"\(s.english)\"")
    }
    let lower = s.english.lowercased()
    for kw in s.keywords where !lower.contains(kw.lowercased()) {
        errors.append("#\(s.id) mot-clé absent: \"\(kw)\"")
    }
    if s.keywords.isEmpty { errors.append("#\(s.id) sans mot-clé") }
    for v in s.acceptedVariants ?? [] where v.lowercased() == s.english.lowercased() {
        errors.append("#\(s.id) variante identique à la canonique: \"\(v)\"")
    }
    if s.french.isEmpty || s.english.isEmpty { errors.append("#\(s.id) champ vide") }
}

// Équilibre des catégories
let byCat = Dictionary(grouping: all, by: \.category).mapValues(\.count)
if byCat.count >= 2,
   let mx = byCat.values.max(), let mn = byCat.values.min(),
   Double(mx) / Double(mn) > 1.5 {
    errors.append("Catégories déséquilibrées: \(byCat.sorted { $0.key < $1.key })")
}

if errors.isEmpty {
    print("✅ \(all.count) phrases valides")
} else {
    errors.forEach { print("❌ \($0)") }
    exit(1)
}
