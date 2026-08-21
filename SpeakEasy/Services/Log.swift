import OSLog

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.speakeasy"

    static let speech   = Logger(subsystem: subsystem, category: "speech")
    static let audio    = Logger(subsystem: subsystem, category: "audio")
    static let scoring  = Logger(subsystem: subsystem, category: "scoring")
    static let data     = Logger(subsystem: subsystem, category: "data")
    static let ui       = Logger(subsystem: subsystem, category: "ui")

    /// Signposts pour Instruments (mesure du pipeline audio).
    static let signposter = OSSignposter(subsystem: subsystem, category: "perf")
}
