import SwiftUI
import UIKit

struct ReadyContent: View {
    let sentence: LearningSentence
    let progressText: String
    let mode: PracticeMode
    let isRevealed: Bool
    let isSpeaking: Bool
    let onListen: () -> Void
    let onReveal: () -> Void
    let onRecord: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            SentenceRow(sentence: sentence, mode: mode,
                        isRevealed: isRevealed, onReveal: onReveal)

            Spacer(minLength: 8)

            VStack(spacing: 18) {
                Button(action: onListen) {
                    Label("Listen", systemImage: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Listen to the English sentence")

                MicrophoneButton(state: .idle, action: onRecord)
            }
        }
    }
}

struct RecordingContent: View {
    let sentence: LearningSentence
    let progressText: String
    let elapsed: TimeInterval
    let meter: AudioLevelMeter
    let isActive: Bool
    let finalized: String
    let volatile: String
    let onStop: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 48
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        VStack(spacing: 24) {
            Text(progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Text(sentence.french)
                .font(.title2)
                .multilineTextAlignment(.center)
                .opacity(0.6)

            Spacer(minLength: 16)

            VStack(spacing: 20) {
                Text(elapsedString)
                                    .font(.system(size: timerSize, weight: .light, design: .rounded))
                                    .monospacedDigit()
                                    .accessibilityLabel("Elapsed time \(Int(elapsed)) seconds")

                                // Live transcript — suppressed while VoiceOver is already speaking.
                                if !voiceOverEnabled {
                                    LiveTranscriptView(finalized: finalized, volatile: volatile)
                                }

                                WaveformView(meter: meter, isActive: isActive)

                MicrophoneButton(state: .recording, action: onStop)

                Text("Speak naturally")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var elapsedString: String {
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }
}

struct ProcessingContent: View {
    let progressText: String

    var body: some View {
        VStack(spacing: 24) {
            Text(progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            VStack(spacing: 16) {
                ProgressView().controlSize(.large)
                Text("Checking…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Checking your pronunciation")
    }
}

struct ErrorContent: View {
    let progressText: String
    let error: RecordingError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            VStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text(error.errorDescription ?? "Something went wrong.")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 12) {
                if requiresSettings {
                    Button {
                        openSettings()
                    } label: {
                        Text("Open Settings")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(action: onRetry) {
                        Text("Try again")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }

    private var iconName: String {
        switch error {
        case .microphoneDenied, .speechDenied:
            return "mic.slash.fill"
        case .noSpeech:
            return "waveform.slash"
        default:
            return "exclamationmark.triangle"
        }
    }

    private var requiresSettings: Bool {
        switch error {
        case .microphoneDenied, .speechDenied:
            return true
        default:
            return false
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
