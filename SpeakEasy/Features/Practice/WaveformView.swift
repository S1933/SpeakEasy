import SwiftUI

struct WaveformView: View {
    let meter: AudioLevelMeter
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var frameRate: Double { reduceMotion ? 10 : 30 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / frameRate, paused: !isActive)) { _ in
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                let samples = meter.waveform
                guard !samples.isEmpty else { return }

                let barWidth = size.width / CGFloat(samples.count)
                let inset = barWidth * 0.25
                let midY = size.height / 2

                // Un seul Path pour toutes les barres → une seule primitive de dessin.
                var path = Path()
                for (index, sample) in samples.enumerated() {
                    let height = max(2, CGFloat(0.06 + 0.94 * sample) * size.height)
                    let rect = CGRect(
                        x: CGFloat(index) * barWidth + inset,
                        y: midY - height / 2,
                        width: barWidth - inset * 2,
                        height: height
                    )
                    path.addRoundedRect(in: rect, cornerSize: CGSize(width: 1.5, height: 1.5))
                }
                context.fill(path, with: .color(.accentColor.opacity(0.55)))
            }
        }
        .frame(height: 60)
        .accessibilityHidden(true)
    }
}

#Preview {
    WaveformView(meter: AudioLevelMeter(), isActive: true)
        .padding()
}
