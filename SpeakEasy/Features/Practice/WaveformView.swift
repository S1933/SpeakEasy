import SwiftUI

struct WaveformView: View {
    let amplitude: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let bars = 32
                let barWidth = size.width / CGFloat(bars)
                let time = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<bars {
                    let phase = time * 2 + Double(i) * 0.3
                    let envelope = 0.15 + 0.85 * amplitude
                    let h = (0.15 + 0.85 * envelope * abs(sin(phase))) * size.height
                    let x = CGFloat(i) * barWidth
                    let rect = CGRect(
                        x: x + barWidth * 0.2,
                        y: (size.height - h) / 2,
                        width: barWidth * 0.6,
                        height: h
                    )
                    let path = Path(roundedRect: rect, cornerRadius: barWidth * 0.3)
                    context.fill(path, with: .color(.primary.opacity(0.35)))
                }
            }
        }
        .frame(height: 60)
        .accessibilityHidden(true)
    }
}

#Preview {
    WaveformView(amplitude: 0.5)
        .padding()
}
