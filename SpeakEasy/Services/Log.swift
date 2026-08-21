import os
import Foundation

enum Log {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "com.speakeasy"

    nonisolated static let speech   = Logger(subsystem: subsystem, category: "speech")
    nonisolated static let audio    = Logger(subsystem: subsystem, category: "audio")
    nonisolated static let scoring  = Logger(subsystem: subsystem, category: "scoring")
    nonisolated static let data     = Logger(subsystem: subsystem, category: "data")
    nonisolated static let ui       = Logger(subsystem: subsystem, category: "ui")

    /// Signposts for Instruments (audio pipeline measurement).
    nonisolated static let signposter = OSSignposter(subsystem: subsystem, category: "perf")
}
