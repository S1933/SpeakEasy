import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @State private var showingResetConfirmation = false

    var body: some View {
        Form {
            Section("Voice") {
                Picker("Voice", selection: voiceBinding) {
                    ForEach(VoiceOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            }

            Section("Session") {
                Picker("Sentences per session", selection: sessionBinding) {
                    ForEach(SessionSizeOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Text("Reset progress")
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .confirmationDialog(
            "Reset all progress?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your practice history.")
        }
    }

    private var settings: AppSettings {
        if let existing = settingsList.first { return existing }
        let new = AppSettings()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    private var voiceBinding: Binding<VoiceOption> {
        Binding(
            get: { VoiceOption(rawValue: settings.voiceLocale) ?? .enUS },
            set: {
                settings.voiceLocale = $0.rawValue
                try? modelContext.save()
            }
        )
    }

    private var sessionBinding: Binding<SessionSizeOption> {
        Binding(
            get: { SessionSizeOption(rawValue: settings.sessionSize) ?? .ten },
            set: {
                settings.sessionSize = $0.rawValue
                try? modelContext.save()
            }
        )
    }

    private func reset() {
        try? modelContext.delete(model: SentenceProgress.self)
        try? modelContext.save()
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [SentenceProgress.self, AppSettings.self], inMemory: true)
}