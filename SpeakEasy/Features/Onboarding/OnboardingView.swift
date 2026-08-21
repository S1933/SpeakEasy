import SwiftUI
import Speech

struct OnboardingView: View {
    let locale: Locale
    let assets: SpeechAssetManager
    let onReady: () -> Void

    @State private var micGranted = false
    @State private var speechGranted = false

    private var isReady: Bool { micGranted && speechGranted && assets.state == .installed }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Let's set up SpeakEasy")
                .font(.largeTitle.weight(.semibold))
            Text("Two permissions and a one-time download. Everything runs on your device — nothing is sent to a server.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                checklistRow("mic.fill", "Microphone", done: micGranted)
                checklistRow("waveform", "Speech recognition", done: speechGranted)
                assetRow
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Spacer()

            Button(action: onReady) {
                Text("Get started")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isReady)
        }
        .padding(24)
        .task { await runSetup() }
    }

    private func checklistRow(_ icon: String, _ label: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .foregroundStyle(done ? .green : .secondary)
            Text(label)
            Spacer()
        }
    }

    @ViewBuilder
    private var assetRow: some View {
        switch assets.state {
        case .downloading(let p):
            VStack(alignment: .leading, spacing: 6) {
                Text("Downloading English model…").font(.subheadline)
                ProgressView(value: p)
                Text("\(Int(p * 100))%").font(.caption).foregroundStyle(.secondary)
            }
        case .installed:
            checklistRow("arrow.down.circle.fill", "English model", done: true)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.orange)
        case .unsupported:
            Label("English isn't available on this device.", systemImage: "globe.badge.chevron.backward")
                .font(.caption).foregroundStyle(.orange)
        case .unknown:
            ProgressView()
        }
    }

    private func runSetup() async {
        micGranted = await PermissionService.requestMicrophone()
        speechGranted = await PermissionService.requestSpeech() == .authorized
        await assets.check(locale: locale)
        if assets.state != .installed { await assets.install(locale: locale) }
    }
}

#Preview {
    OnboardingView(locale: Locale(identifier: "en-US"),
                   assets: SpeechAssetManager(), onReady: {})
}
