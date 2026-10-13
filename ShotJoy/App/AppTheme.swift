import SwiftUI

enum AppTheme {
    static let coral = Color(red: 1.0, green: 122 / 255.0, blue: 89 / 255.0)
    static let mint = Color(red: 46 / 255.0, green: 196 / 255.0, blue: 182 / 255.0)
    static let cardBackground = Color(.secondarySystemBackground)
    static let warningYellow = Color.yellow

    static var disclaimerFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "cross.case.fill")
                .font(.caption2)
            Text("Educational only — not medical advice. Always follow your prescriber's instructions.")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .accessibilityLabel("Educational only, not medical advice. Always follow your prescriber's instructions.")
    }
}

struct BigActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
