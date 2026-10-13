import SwiftUI

struct AIEngineView: View {
    @State private var configs: [BYOProviderConfig] = []
    @State private var testing: BYOProviderID?
    @State private var testResults: [BYOProviderID: String] = [:]

    var body: some View {
        List {
            Section {
                ForEach(BYOProviderID.allCases, id: \.self) { id in
                    ProviderRow(config: config(for: id),
                                testResult: testResults[id],
                                isTesting: testing == id,
                                hasKey: BYOStore.hasKey(for: id),
                                onTap: { testing = nil })
                }
            } header: {
                Text("Providers")
            } footer: {
                Text("Tap a provider to paste your API key (stored in the iOS Keychain, never synced). Vision tasks skip providers without vision models. The BYO tier is unlimited and never routed through our servers.")
            }
            Section {
                LabeledContent("Text default", value: BYOStore.defaultProvider(for: .text)?.displayName ?? "Apple on-device")
                LabeledContent("Vision default", value: BYOStore.defaultProvider(for: .vision)?.displayName ?? "Cloud (Pro) or manual")
            } header: {
                Text("Routing")
            } footer: {
                Text("Vision tasks (vial label, meal photo) silently skip providers without vision capability.")
            }
        }
        .navigationTitle("AI Engine")
        .onAppear { configs = BYOStore.configs }
    }

    private func config(for id: BYOProviderID) -> BYOProviderConfig {
        configs.first { $0.id == id } ?? BYOStore.config(for: id)
    }
}

struct ProviderRow: View {
    let config: BYOProviderConfig
    let testResult: String?
    let isTesting: Bool
    let hasKey: Bool
    let onTap: () -> Void

    @State private var showEditor = false

    var body: some View {
        Button { showEditor = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(config.id.displayName).font(.body.weight(.medium))
                        if config.supportsVision {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.mint)
                        }
                    }
                    Text(hasKey ? "Key saved" : "No key")
                        .font(.caption)
                        .foregroundStyle(hasKey ? AppTheme.mint : .secondary)
                    if let testResult {
                        Text(testResult)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isTesting {
                    ProgressView()
                } else if config.enabled && hasKey {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.mint)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditor) {
            ProviderEditorView(config: config) { updated in
                BYOStore.saveConfig(updated)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

struct ProviderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var config: BYOProviderConfig
    @State private var apiKey = ""
    @State private var testResult: String?
    @State private var isTesting = false
    let onSave: (BYOProviderConfig) -> Void

    var body: some View {
        NavigationStack {
            Form {
                if config.id == .custom {
                    Section("Endpoint (OpenAI-compatible)") {
                        TextField("Base URL e.g. http://localhost:11434/v1", text: $config.baseURL)
                        TextField("Model name", text: $config.textModel)
                        TextField("Vision model (blank = no vision)", text: Binding(
                            get: { config.visionModel ?? "" },
                            set: { config.visionModel = $0.isEmpty ? nil : $0 }
                        ))
                    }
                } else {
                    Section("Model") {
                        TextField("Text model", text: $config.textModel)
                        TextField("Vision model (blank = no vision)", text: Binding(
                            get: { config.visionModel ?? "" },
                            set: { config.visionModel = $0.isEmpty ? nil : $0 }
                        ))
                    }
                }
                Section("API Key") {
                    SecureField("Paste your API key", text: $apiKey)
                        .textContentType(.password)
                }
                Section("Connection test") {
                    Button {
                        Task { await test() }
                    } label: {
                        if isTesting {
                            ProgressView()
                        } else {
                            Label("Test connection", systemImage: "bolt.horizontal")
                        }
                    }
                    if let testResult {
                        Text(testResult).font(.caption)
                    }
                }
                Section {
                    Toggle("Enabled", isOn: $config.enabled)
                }
            }
            .navigationTitle(config.id.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !apiKey.isEmpty {
                            BYOStore.setAPIKey(apiKey, for: config.id)
                        }
                        onSave(config)
                        dismiss()
                    }
                }
            }
        }
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        if !apiKey.isEmpty {
            BYOStore.setAPIKey(apiKey, for: config.id)
        }
        var cfg = config
        cfg.enabled = true
        let result = await BYOEngine.testConnection(cfg: cfg)
        testResult = (result.success ? "✅ " : "❌ ") + result.message + (result.latencyMS.map { " (\($0)ms)" } ?? "")
    }
}
