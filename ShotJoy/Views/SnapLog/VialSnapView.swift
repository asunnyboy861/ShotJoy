import SwiftUI
import SwiftData
import PhotosUI

struct VialSnapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var jpegData: Data?
    @State private var parsed: ParsedVial?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var mismatchWarning: String?

    @State private var compoundName = ""
    @State private var massText = ""
    @State private var waterText = "2"
    @State private var syringeType: SyringeType = .u100

    var body: some View {
        NavigationStack {
            Form {
                Section("Scan vial label") {
                    if let jpegData, let image = UIImage(data: jpegData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .frame(maxWidth: .infinity)
                            .listRowInsets(EdgeInsets())
                    } else {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Take or choose a label photo", systemImage: "camera.viewfinder")
                        }
                    }
                    if isProcessing {
                        Label("Reading label…", systemImage: "sparkles")
                            .foregroundStyle(AppTheme.mint)
                            .symbolEffect(.variableColor)
                    }
                    if let mismatchWarning {
                        Label(mismatchWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.warningYellow)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextField("Compound name", text: $compoundName)
                    HStack {
                        TextField("Total mg", text: $massText).keyboardType(.decimalPad)
                        TextField("BAC water mL", text: $waterText).keyboardType(.decimalPad)
                    }
                    Picker("Syringe", selection: $syringeType) {
                        ForEach(SyringeType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Confirm details (AI never writes without you)")
                } footer: {
                    Text("Photos are processed in memory only and never stored. AI output is cross-checked against your entered values — mismatch shows a red warning.")
                }

                if let parsed, parsed.readable {
                    Section("AI read") {
                        LabeledContent("Compound", value: parsed.compound)
                        LabeledContent("Total", value: "\(trim(parsed.totalMG)) mg")
                        LabeledContent("Form", value: parsed.formulation)
                    }
                }

                Section {
                    Button {
                        addVial()
                    } label: {
                        Text("Add vial to my meds")
                    }
                    .disabled(compoundName.isEmpty || (Decimal(string: massText) ?? 0) <= 0)
                }
            }
            .navigationTitle("Scan vial")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let jpeg = image.jpegData(compressionQuality: 0.7) {
                        jpegData = jpeg
                        await recognize()
                    }
                }
            }
            .onChange(of: massText) { _, _ in crossValidate() }
        }
    }

    private func recognize() async {
        isProcessing = true
        errorMessage = nil
        mismatchWarning = nil
        defer { isProcessing = false }

        let byoProvider = BYOStore.defaultProvider(for: .vision)
        let route = AIRouter.route(for: .vision,
                                   pro: purchaseManager.isPro,
                                   cloudQuota: purchaseManager.hasCloudAI,
                                   byoProvider: byoProvider,
                                   onDeviceAvailable: AppleOnDeviceAI.shared.isAvailable,
                                   onDeviceQuotaRemaining: AppleOnDeviceAI.shared.quotaRemaining)
        do {
            switch route {
            case .byoProvider:
                guard let id = byoProvider, let cfg = BYOStore.configs.first(where: { $0.id == id }) else {
                    errorMessage = "Selected provider isn't ready."
                    return
                }
                let b64 = jpegData!.base64EncodedString()
                let messages: [[String: Any]] = [
                    ["role": "user", "content": [
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]],
                        ["type": "text", "text": "Extract from this medicine vial label photo. Reply ONLY JSON: {\"compound\":\"string\",\"total_mg\":number,\"formulation\":\"lyophilized|solution\"}. If unreadable, reply {\"error\":\"unreadable\"}."]
                    ]]
                ]
                let json = try await BYOEngine.chat(messages: messages, cfg: cfg, kind: .vision, maxTokens: 8192)
                parsed = ParsedVial(fromJSON: json)
            case .sharedWorker:
                parsed = try await GLMCloudService.parseVialLabel(jpegData: jpegData!, appTransactionJWS: purchaseManager.lastJWSRepresentation)
            default:
                errorMessage = "Label scanning needs cloud vision — go Pro, add your own key, or enter manually below."
                return
            }
            if let p = parsed {
                if p.readable {
                    if compoundName.isEmpty { compoundName = p.compound }
                    if massText.isEmpty { massText = trim(p.totalMG) }
                } else {
                    errorMessage = "Couldn't read the label clearly. Enter the values manually."
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func crossValidate() {
        guard let entered = Decimal(string: massText), let p = parsed, p.readable else {
            mismatchWarning = nil
            return
        }
        if abs(NSDecimalNumber(decimal: entered - p.totalMG).doubleValue) > 0.01 {
            mismatchWarning = "Mismatch: label reads \(trim(p.totalMG)) mg but you entered \(trim(entered)) mg. The value you type wins — double-check the vial."
        } else {
            mismatchWarning = nil
        }
    }

    private func addVial() {
        crossValidate()
        guard let mass = Decimal(string: massText), mass > 0 else { return }
        let water = Decimal(string: waterText) ?? 2
        let vial = Vial(compoundName: compoundName, massMG: mass, bacWaterML: water, remainingMG: mass, syringeType: syringeType.rawValue, reconstitutedAt: Date())
        let compound = Compound(name: compoundName, kind: "peptide", halfLifeHours: CompoundPresets.all.first { $0.name == compoundName }?.halfLifeHours ?? 24, isPreset: false)
        modelContext.insert(compound)
        vial.compound = compound
        modelContext.insert(vial)
        try? modelContext.save()
        dismiss()
    }

    private func trim(_ d: Decimal) -> String {
        String(format: "%.1f", NSDecimalNumber(decimal: d).doubleValue)
    }
}
