import Foundation

/// Une portion de lecture continue. Une interruption en ferme un et en ouvre un autre.
struct ReadingSegment: Sendable {
    /// Index du token de référence où ce segment commence.
    let referenceStart: Int
    var hypothesis: [HypToken] = []
    /// Durée réellement passée à lire dans ce segment, hors pause.
    var activeDuration: TimeInterval = 0
}

struct ReadingSession: Sendable {
    var segments: [ReadingSegment] = [ReadingSegment(referenceStart: 0)]

    var current: ReadingSegment {
        get { segments[segments.count - 1] }
        set { segments[segments.count - 1] = newValue }
    }

    /// Le temps de pause est exclu : sinon une interruption de deux minutes
    /// écraserait le débit et rendrait la note absurde.
    var activeDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.activeDuration }
    }

    mutating func openSegment(at referenceIndex: Int) {
        segments.append(ReadingSegment(referenceStart: referenceIndex))
    }
}