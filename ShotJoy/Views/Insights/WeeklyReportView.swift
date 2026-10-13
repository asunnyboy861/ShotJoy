import SwiftUI
import SwiftData

struct WeeklyReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DoseLog.loggedAt, order: .reverse) private var doseLogs: [DoseLog]
    @Query(sort: \SymptomLog.loggedAt, order: .reverse) private var symptomLogs: [SymptomLog]
    @Query(sort: \MealLog.loggedAt, order: .reverse) private var mealLogs: [MealLog]
    @Query private var vials: [Vial]
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var cards: [InsightCard] = []
    @State private var localSummary: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEnvelope = true
    @State private var paywallVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if showEnvelope {
                    envelopeCard
                } else if !cards.isEmpty {
                    ForEach(cards) { card in
                        InsightCardView(card: card)
                    }
                } else if let localSummary {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("This week, in your device's words", systemImage: "iphone.gen3")
                            .font(.headline)
                        Text(localSummary)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
                    upsellCard
                }
                if let errorMessage {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try again") { Task { await generate() } }
                            .font(.caption.bold())
                    }
                }
                AppTheme.disclaimerFooter
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Weekly insight")
        .background(Color(.systemBackground))
        .task { if cards.isEmpty && localSummary == nil && !isLoading { await generate() } }
        .sheet(isPresented: $paywallVisible) {
            PaywallView()
        }
    }

    private var envelopeCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.coral)
            Text("Your week is ready")
                .font(.title3.bold())
            if isLoading {
                ProgressView("Reading your logs…")
            } else {
                Button {
                    withAnimation(.spring(response: 0.5)) { showEnvelope = false }
                } label: {
                    Text("Open report")
                }
                .buttonStyle(BigActionButtonStyle())
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(AppTheme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 24))
    }

    private var upsellCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Want the deeper 'why'?", systemImage: "sparkles")
                .font(.headline)
            Text("Pro unlocks GLM-powered insights: which sites feel better, how symptoms cluster after dose changes, and your protein streaks — with confidence scores.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("See Pro") { paywallVisible = true }
                .font(.subheadline.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }

    private func generate() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let summary = AIRouter.aggregateSummary(doseLogs: doseLogs, symptomLogs: symptomLogs, mealLogs: mealLogs, weightEntries: [], vials: vials)
        let byoProvider = BYOStore.defaultProvider(for: .text)
        let onDevice = AppleOnDeviceAI.shared
        let route = AIRouter.route(for: .text,
                                   pro: purchaseManager.isPro,
                                   cloudQuota: purchaseManager.hasCloudAI,
                                   byoProvider: byoProvider,
                                   onDeviceAvailable: onDevice.isAvailable,
                                   onDeviceQuotaRemaining: onDevice.quotaRemaining)
        switch route {
        case .byoProvider:
            if let id = byoProvider, let cfg = BYOStore.configs.first(where: { $0.id == id }) {
                do {
                    let messages: [[String: Any]] = [
                        ["role": "system", "content": "You write supportive GLP-1 tracking insights. Educational only, never medical advice, never dose suggestions. Reply ONLY JSON: {\"insights\":[{\"headline\":\"...\",\"why\":\"...\",\"confidence\":0.0}]}"],
                        ["role": "user", "content": "Write exactly 3 insights from this aggregate data: \(summary)"]
                    ]
                    let json = try await BYOEngine.chat(messages: messages, cfg: cfg, kind: .text, maxTokens: 4096)
                    cards = decodeInsights(json)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .sharedWorker:
            do {
                cards = try await GLMCloudService.weeklyInsight(summaryJSON: summary, appTransactionJWS: purchaseManager.lastJWSRepresentation)
            } catch {
                errorMessage = error.localizedDescription
                await fallbackLocal()
            }
        case .onDeviceApple:
            await fallbackLocal()
        case .blocked:
            errorMessage = "Free on-device AI for today is used up. Pro or your own API key unlocks unlimited insights."
            await fallbackLocal()
        }
    }

    private func fallbackLocal() async {
        let entries = AIRouter.weekEntries(doseLogs: doseLogs, symptomLogs: symptomLogs, mealLogs: mealLogs)
        do {
            localSummary = try await AppleOnDeviceAI.shared.summarizeWeek(entries: entries)
        } catch {
            localSummary = plainFallback(entries: entries)
        }
    }

    private func plainFallback(entries: [DayEntry]) -> String {
        let shots = entries.filter { $0.shotLogged }.count
        let nauseaDays = entries.filter { $0.nauseaScore > 0 }.count
        let avgProtein = entries.map { $0.proteinG }.reduce(0, +) / max(entries.count, 1)
        return "You logged \(shots) shot(s) this week and felt nauseous on \(nauseaDays) day(s). Your average logged protein was about \(avgProtein)g per day — keeping protein up helps protect muscle. If anything worries you, check in with your clinician."
    }

    private func decodeInsights(_ json: String) -> [InsightCard] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(InsightEnvelope.self, from: data) else { return [] }
        return decoded.insights
    }
}

struct InsightCardView: View {
    let card: InsightCard
    @State private var showWhy = false

    private var confidenceColor: Color {
        card.confidence >= 0.85 ? AppTheme.mint : AppTheme.warningYellow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.headline)
                    .font(.headline)
                Spacer()
                Text("\(Int(card.confidence * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(confidenceColor)
                    .padding(6)
                    .background(confidenceColor.opacity(0.14), in: Capsule())
            }
            Button {
                withAnimation { showWhy.toggle() }
            } label: {
                Label(showWhy ? "Hide why" : "Why?", systemImage: showWhy ? "chevron.up" : "chevron.down")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
            if showWhy {
                Text(card.why)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}
