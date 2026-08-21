import SwiftUI

enum MicrophoneVisualState {
    case idle
    case recording
    case processing
    case disabled
}

struct MicrophoneButton: View {
    let state: MicrophoneVisualState
    let action: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var diameter: CGFloat = 96
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 36

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(backgroundStyle)
                        .frame(width: diameter, height: diameter)

                    iconView
                        .font(.system(size: iconSize))
                }

                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch state {
        case .recording: return AnyShapeStyle(Color.red.opacity(0.15))
        default: return AnyShapeStyle(Color.secondary.opacity(0.12))
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .idle, .disabled:
            Image(systemName: "mic.fill")
                .foregroundStyle(.primary)
        case .recording:
            Image(systemName: "stop.fill")
                .foregroundStyle(.red)
        case .processing:
            ProgressView()
                .controlSize(.large)
        }
    }

    private var label: String {
        switch state {
        case .idle: return "Speak"
        case .recording: return "Recording…"
        case .processing: return "Checking…"
        case .disabled: return "Speak"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return "Start recording"
        case .recording: return "Stop recording"
        case .processing: return "Processing recording"
        case .disabled: return "Start recording, currently unavailable"
        }
    }

    private var isDisabled: Bool {
        switch state {
        case .disabled, .processing: return true
        case .idle, .recording: return false
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        MicrophoneButton(state: .idle) {}
        MicrophoneButton(state: .recording) {}
        MicrophoneButton(state: .processing) {}
        MicrophoneButton(state: .disabled) {}
    }
    .padding()
}
