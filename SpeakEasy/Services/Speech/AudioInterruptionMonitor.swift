@preconcurrency import os
@preconcurrency import AVFoundation
@preconcurrency import Foundation

@MainActor
final class AudioInterruptionMonitor {
    enum Event: Sendable {
        case interrupted          // appel, Siri…
        case resumable            // l'interruption est finie, reprise possible
        case routeLost            // périphérique d'entrée débranché
    }

    private var observers: [NSObjectProtocol] = []
    private let handler: @MainActor (Event) -> Void

    init(handler: @escaping @MainActor (Event) -> Void) {
        self.handler = handler
        subscribe()
    }

    deinit {
        // NotificationCenter est thread-safe pour removeObserver.
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func subscribe() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [handler] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            MainActor.assumeIsolated {
                switch type {
                case .began:
                    Log.audio.notice("Interruption début")
                    handler(.interrupted)
                case .ended:
                    let optsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let opts = AVAudioSession.InterruptionOptions(rawValue: optsRaw)
                    if opts.contains(.shouldResume) { handler(.resumable) }
                @unknown default:
                    break
                }
            }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [handler] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
            MainActor.assumeIsolated {
                if reason == .oldDeviceUnavailable {
                    Log.audio.notice("Périphérique d'entrée retiré")
                    handler(.routeLost)
                }
            }
        })
    }
}
