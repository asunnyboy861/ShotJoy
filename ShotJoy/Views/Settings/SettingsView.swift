import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var healthKit = HealthKitService.shared
    @State private var showPaywall = false
    @State private var showHealthKitInfo = false
    @State private var faceIDEnabled = FaceIDService.isLockEnabled
    @State private var proteinTargetText = ""
    @State private var reminderEnabled = false
    @Query private var goalsList: [GoalSettings]

    var body: some View {
        NavigationStack {
            Form {
                proSection
                healthSection
                trackingSection
                aiEngineSection
                securitySection
                legalSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showHealthKitInfo) { HealthKitInfoView() }
            .onAppear {
                if let goals = goalsList.first {
                    proteinTargetText = trim(goals.proteinTargetG)
                    reminderEnabled = goals.reminderEnabled
                }
            }
        }
    }

    private var proSection: some View {
        Section {
            if purchaseManager.isPro {
                Label("Pro is active — thank you!", systemImage: "crown.fill")
                    .foregroundStyle(AppTheme.coral)
                Button("Manage Subscription") {
                    Task { @MainActor in
                        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                        try? await AppStore.showManageSubscriptions(in: scene)
                    }
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label("Upgrade to Pro", systemImage: "crown.fill")
                        .foregroundStyle(AppTheme.coral)
                }
                Button("Restore Purchases") {
                    Task { await purchaseManager.restorePurchases() }
                }
            }
        } header: {
            Text("ShotJoy Pro")
        } footer: {
            Text("Core tracking is free forever. Pro adds unlimited AI insights, cloud vision and PDF reports.")
        }
    }

    private var healthSection: some View {
        Section {
            HStack {
                Image(systemName: "heart.circle.fill").foregroundStyle(.red).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HealthKit Integration").font(.headline)
                    Text("Sync weight to Apple Health via HealthKit").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showHealthKitInfo = true } label: {
                    Text("Learn More").font(.caption).foregroundStyle(.blue)
                }.buttonStyle(.plain)
            }.padding(.vertical, 2)
            Toggle("Sync weight to HealthKit", isOn: Binding(
                get: { healthKit.isEnabled },
                set: { newValue in
                    healthKit.isEnabled = newValue
                    if newValue {
                        healthKit.requestAuthorization { _ in }
                    }
                }
            ))
        } header: {
            HStack {
                Text("Apple Health (HealthKit)")
                Spacer()
                Image(systemName: "heart.text.square.fill").foregroundStyle(.red)
            }
        } footer: {
            Text("This app uses the HealthKit framework to write your weight entries to the Apple Health app and read weight, sleep and steps for your progress charts. This requires your explicit permission.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var trackingSection: some View {
        Section {
            HStack {
                Text("Daily protein goal (g)")
                Spacer()
                TextField("100", text: $proteinTargetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onChange(of: proteinTargetText) { _, value in
                        if let goals = goalsList.first, let v = Decimal(string: value), v > 0 {
                            goals.proteinTargetG = v
                            try? modelContext.save()
                        }
                    }
            }
            Toggle("Shot Day reminders", isOn: Binding(
                get: { reminderEnabled },
                set: { newValue in
                    reminderEnabled = newValue
                    if let goals = goalsList.first {
                        goals.reminderEnabled = newValue
                        try? modelContext.save()
                    }
                    Task {
                        if newValue {
                            let ok = await NotificationService.requestPermission()
                            if ok, let goals = goalsList.first {
                                await NotificationService.scheduleShotDay(weekday: goals.reminderWeekday, hour: goals.reminderHour, minute: goals.reminderMinute)
                            }
                        } else {
                            await NotificationService.cancelAll()
                        }
                    }
                }
            ))
        } header: {
            Text("Tracking")
        }
    }

    private var aiEngineSection: some View {
        Section {
            NavigationLink {
                AIEngineView()
            } label: {
                Label("AI Engine (BYO)", systemImage: "cpu.fill")
            }
            if AppleOnDeviceAI.shared.isAvailable {
                Label("Apple Intelligence available", systemImage: "apple.logo")
                    .foregroundStyle(AppTheme.mint)
            } else {
                Label("Apple Intelligence unavailable on this device — configure an API key for AI features.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("AI")
        } footer: {
            Text("Free tier: Apple on-device AI, 5 tasks/day. Pro: unlimited on-device + cloud. BYO: your own keys for any provider.")
        }
    }

    private var securitySection: some View {
        Section {
            Toggle("Lock with Face ID", isOn: Binding(
                get: { faceIDEnabled },
                set: {
                    faceIDEnabled = $0
                    FaceIDService.isLockEnabled = $0
                }
            ))
        } header: {
            Text("Privacy & Security")
        } footer: {
            Text("Your data stays on-device with AES-256-GCM encryption. Keys live in the Keychain. iCloud sync is optional and off by default.")
        }
    }

    private var legalSection: some View {
        Section {
            Link(destination: URL(string: "https://asunnyboy861.github.io/shotjoy/support.html")!) {
                Label("Support", systemImage: "questionmark.circle")
            }
            Link(destination: URL(string: "https://asunnyboy861.github.io/shotjoy/privacy.html")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            Link(destination: URL(string: "https://asunnyboy861.github.io/shotjoy/terms.html")!) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            NavigationLink(destination: PricingTransparencyView()) {
                Label("Pricing, in plain text", systemImage: "tag")
            }
            NavigationLink(destination: ContactSupportView()) {
                Label("Contact Support", systemImage: "envelope")
            }
        } header: {
            Text("Legal & Support")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Category", value: "Health & Fitness · 16+")
            LabeledContent("Data collected", value: "None")
        } header: {
            Text("About")
        } footer: {
            Text("\(appVersion)\nShotJoy is a recording and education tool — not a medical device. It never suggests doses. Educational only, not medical advice.")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private func trim(_ d: Decimal) -> String {
        let s = String(format: "%.0f", NSDecimalNumber(decimal: d).doubleValue)
        return s
    }
}
