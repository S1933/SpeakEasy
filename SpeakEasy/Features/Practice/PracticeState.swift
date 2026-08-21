import Foundation

enum PracticeState: Sendable {
    case ready
    case recording
    case processing
    case result(AttemptResult)
}

struct AttemptResult: Sendable, Equatable {
    let expected: String
    let transcript: String
    let score: Int
    let tokens: [TokenResult]
}

enum TokenStatus: Sendable, Equatable {
    case correct
    case missing
    case incorrect(actual: String)
    case extra
}

struct TokenResult: Sendable, Equatable {
    let text: String
    let status: TokenStatus
}
