#!/usr/bin/env swift
import Foundation

// Validation du contenu de lecture avant enrichissement (Phase 1).
// Usage : swift Scripts/validate_reading.swift

let url = URL(fileURLWithPath: "SpeakEasy/Data/reading_texts.json")
struct Line: Codable { let id: Int; let speaker: String?; let text: String }
struct Text: Codable {
    let id: Int
    let kind: String
    let title: String
    let difficulty: Int
    let lines: [Line]
}

let data = try Data(contentsOf: url)
let all = try JSONDecoder().decode([Text].self, from: data)

var errors: [String] = []

// Unique ids
let dupes = Dictionary(grouping: all, by: \.id).filter { $1.count > 1 }
if !dupes.isEmpty { errors.append("Duplicate text ids: \(dupes.keys.sorted())") }

for t in all {
    let words = t.lines.reduce(0) { $0 + $1.text.split(separator: " ").count }

    if !(80...120).contains(words) {
        errors.append("#\(t.id): \(words) mots, hors de la plage 80-120")
    }

    for line in t.lines where line.text.rangeOfCharacter(from: .decimalDigits) != nil {
        errors.append("#\(t.id): chiffre en écriture numérique — écrire en toutes lettres")
    }

    if t.kind == "conversation" {
        let speakers = t.lines.compactMap { $0.speaker }
        if Set(speakers).count < 2 {
            errors.append("#\(t.id): dialogue avec moins de deux personnages")
        }
    } else if t.kind == "story" {
        if t.lines.contains(where: { $0.speaker != nil }) {
            errors.append("#\(t.id): récit avec un personnage renseigné")
        }
    } else {
        errors.append("#\(t.id): kind inconnu '\(t.kind)'")
    }
}

if errors.isEmpty {
    print("✅ \(all.count) textes de lecture valides")
} else {
    errors.forEach { print("❌ \($0)") }
    exit(1)
}