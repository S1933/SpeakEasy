import SwiftUI

/// Speaker picker for dialogues. Pushes `.read(text:, spokenSpeaker:)` onto
/// the host NavigationStack via `onStart`. For stories, this screen is
/// skipped — `ReadingFlowView` pushes `.read(text:, spokenSpeaker: nil)`
/// directly.
struct ReadingSetupView: View {
    let text: ReadingText
    var onStart: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text.title)
                    .font(.title.weight(.semibold))
                Text("Difficulty \(text.difficulty)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text("Choose your role")
                    .font(.headline)
                Text("The app will speak the other characters' lines so you can focus on yours.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                speakerButton("Read all characters",
                              subtitle: "No TTS, you read everything.",
                              value: nil)
                ForEach(text.speakers, id: \.self) { speaker in
                    speakerButton("Read \(speaker)",
                                  subtitle: "App speaks the other \(text.speakers.count - 1) role\(text.speakers.count - 1 == 1 ? "" : "s").",
                                  value: speaker)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func speakerButton(_ title: String, subtitle: String, value: String? = nil) -> some View {
        Button {
            onStart(value)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
