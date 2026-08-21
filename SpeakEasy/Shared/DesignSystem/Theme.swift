import SwiftUI

/// Minimal design system — WCAG contrast guaranteed on primary actions.
enum Theme {
    /// Controlled brand color, NOT the system `.tint` (which the user can
    /// choose as pale yellow → unreadable white). To be replaced by
    /// `Color("BrandPrimary")` once the asset is created in Assets.xcassets.
    static let brand = Color(uiColor: .systemIndigo)

    /// Text color guaranteeing AA contrast on `background`.
    static func onColor(for background: Color) -> Color {
        background.relativeLuminance > 0.45 ? .black : .white
    }
}

extension Color {
    /// WCAG relative luminance.
    var relativeLuminance: Double {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        #else
        return 0.5
        #endif
    }
}

/// Primary button style, single and reused everywhere.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.brand.opacity(isEnabled ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Theme.onColor(for: Theme.brand))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
