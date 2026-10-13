import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var purchasing = false
    @State private var purchaseMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if purchaseManager.products.isEmpty {
                        VStack(spacing: 10) {
                            if purchaseManager.isLoading {
                                ProgressView()
                            } else {
                                Text(purchaseManager.loadError ?? "Prices load from the App Store. Check your connection and try Restore.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                    } else {
                        tierCards
                    }
                    restoreAndManage
                    legalLinks
                    autoRenewalDisclosure
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("ShotJoy Pro")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await purchaseManager.loadProducts() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.coral)
            Text("Unlock Pro")
                .font(.title.bold())
            Text("Core tracking is free forever. Pro adds weekly AI insights, cloud photo scanning, titration mode and doctor-ready PDF reports.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var tierCards: some View {
        VStack(spacing: 12) {
            if let yearly = purchaseManager.yearlyProduct {
                TierCard(product: yearly,
                         title: "Pro Annual",
                         subtitle: "7-day free trial · best value",
                         badge: "SAVE 58%",
                         highlight: true) { await buy(yearly) }
            }
            if let monthly = purchaseManager.monthlyProduct {
                TierCard(product: monthly,
                         title: "Pro Monthly",
                         subtitle: "Try it for a month",
                         badge: nil,
                         highlight: false) { await buy(monthly) }
            }
            if let lifetime = purchaseManager.lifetimeProduct {
                TierCard(product: lifetime,
                         title: "BYO Lifetime",
                         subtitle: "One-time. Uses your own AI keys (GLM, OpenAI, Claude, Gemini, DeepSeek, custom) — no cloud quota from us.",
                         badge: "OWN IT",
                         highlight: false) { await buy(lifetime) }
            }
        }
    }

    private var restoreAndManage: some View {
        VStack(spacing: 8) {
            Button("Restore Purchases") {
                Task { await purchaseManager.restorePurchases() }
            }
            .font(.subheadline)
            if purchaseManager.isPro {
                Button("Manage Subscription") {
                    Task { @MainActor in
                        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                        try? await AppStore.showManageSubscriptions(in: scene)
                    }
                }
                .font(.subheadline)
            }
            if let message = purchaseMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("Privacy Policy", destination: URL(string: "https://asunnyboy861.github.io/ShotJoy/privacy.html")!)
            Link("Terms of Use", destination: URL(string: "https://asunnyboy861.github.io/ShotJoy/terms.html")!)
            Link("Support", destination: URL(string: "https://asunnyboy861.github.io/ShotJoy/support.html")!)
        }
        .font(.caption2)
        .tint(AppTheme.coral)
    }

    private var autoRenewalDisclosure: some View {
        Text("Subscriptions auto-renew unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your App Store settings. Payment is charged to your Apple ID.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private func buy(_ product: Product) async {
        purchasing = true
        let ok = await purchaseManager.purchase(product)
        purchasing = false
        purchaseMessage = ok ? "You're Pro — welcome aboard! 🎉" : nil
        if ok {
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        }
    }
}

struct TierCard: View {
    let product: Product
    let title: String
    let subtitle: String
    let badge: String?
    let highlight: Bool
    let onBuy: () async -> Void

    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .padding(5)
                        .background(AppTheme.mint.opacity(0.16), in: Capsule())
                        .foregroundStyle(AppTheme.mint)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.title3.bold())
            }
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                Task { await onBuy() }
            } label: {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    Text(title.contains("Lifetime") ? "Buy once" : "Subscribe")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(highlight ? AppTheme.coral : AppTheme.mint)
            .disabled(busy)
        }
        .padding()
        .background(highlight ? AppTheme.coral.opacity(0.1) : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20).stroke(highlight ? AppTheme.coral.opacity(0.5) : .clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
    }
}

struct PricingTransparencyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Free forever", systemImage: "gift.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.mint)
                Text("The calculator, shot logging, body-map rotation, reminders, inventory, symptoms, goals, HealthKit and encryption are free — no trial, no catch.")
                    .font(.subheadline)
                Label("Pro: $9.99/month or $49.99/year (7-day free trial)", systemImage: "crown.fill")
                    .font(.headline)
                Text("Unlimited on-device AI, 30 cloud scans/month, GLM weekly insights, titration mode, PDF reports and all future Pro features.")
                    .font(.subheadline)
                Label("BYO Lifetime: $39.99 once", systemImage: "key.fill")
                    .font(.headline)
                Text("All Pro features forever, powered by your own AI keys across GLM, OpenAI, Claude, Gemini, DeepSeek or any OpenAI-compatible endpoint.")
                    .font(.subheadline)
                Text("Every price on this page matches the App Store exactly. No hidden tiers, no dark patterns.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AppTheme.disclaimerFooter
            }
            .padding()
        }
        .navigationTitle("Pricing, in plain text")
        .background(Color(.systemBackground))
    }
}
