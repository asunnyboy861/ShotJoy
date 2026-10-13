import SwiftUI
import HealthKit

struct HealthKitInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                    Text("HealthKit Integration")
                        .font(.title.bold())
                    Text("ShotJoy integrates with Apple Health through the HealthKit framework to keep your health records in one place.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(icon: "scalemass.fill", title: "Writes", detail: "Your weight logs are saved to Apple Health as body-mass samples.")
                        InfoRow(icon: "figure.walk", title: "Reads", detail: "Weight, steps and sleep summaries are read to enrich your progress charts.")
                        InfoRow(icon: "lock.shield", title: "Permission", detail: "Nothing is read or written until you approve the HealthKit permission dialog. Toggle it off anytime in Settings.")
                        InfoRow(icon: "hand.raised.fill", title: "No cloud", detail: "HealthKit data is never sent to any server. It stays on your device and your Apple Health store.")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.red)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
