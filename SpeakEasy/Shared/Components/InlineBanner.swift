import SwiftUI

/// Bandeau non bloquant en haut de l'écran (S3.1).
struct InlineBanner: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.orange)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    InlineBanner(icon: "exclamationmark.triangle",
                 text: "Progress won't be saved this session.")
}
