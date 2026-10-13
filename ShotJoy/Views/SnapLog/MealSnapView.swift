import SwiftUI
import SwiftData
import PhotosUI

struct MealSnapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var jpegData: Data?
    @State private var parsed: ParsedMeal?
    @State private var candidateIndex = 0
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var routeMessage: String?
    @State private var showManualEntry = false
    @State private var manualTitle = ""
    @State private var manualCalories = ""
    @State private var manualProtein = ""

    private var activeCandidate: ParsedMeal.Candidate? {
        guard let parsed else { return nil }
        if candidateIndex == 0 {
            return ParsedMeal.Candidate(title: parsed.title, calories: parsed.calories, proteinG: parsed.proteinG, carbsG: parsed.carbsG, fatG: parsed.fatG)
        }
        return parsed.candidates.indices.contains(candidateIndex) ? parsed.candidates[candidateIndex] : nil
    }

    private var confidence: Double { parsed?.confidence ?? 0 }
    private var needsConfirmation: Bool { confidence < 0.85 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let jpegData, UIImage(data: jpegData) != nil {
                        Image(uiImage: UIImage(data: jpegData)!)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        if isProcessing {
                            Label("Reading your plate…", systemImage: "sparkles")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mint)
                                .symbolEffect(.variableColor)
                        }
                        if let parsed {
                            candidateCard(parsed: parsed)
                        }
                        if let routeMessage {
                            Label(routeMessage, systemImage: "iphone.gen3")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let errorMessage {
                            VStack(spacing: 8) {
                                Label(errorMessage, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.warningYellow)
                                Button("Enter manually instead") { showManualEntry = true }
                                    .font(.caption.bold())
                            }
                        }
                    } else {
                        placeholder
                    }

                    if showManualEntry {
                        manualEntryCard
                    }
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Snap a meal")
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
        }
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.coral)
                    Text("Take or choose a meal photo")
                        .font(.headline)
                    Text("AI estimates macros with a confidence score. Low confidence = you pick from top candidates. Photos stay in memory only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(30)
                .frame(maxWidth: .infinity)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            Button("Enter manually instead") { showManualEntry = true }
                .font(.caption)
        }
    }

    private func candidateCard(parsed: ParsedMeal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(activeCandidate?.title ?? "Meal")
                    .font(.headline)
                Spacer()
                Text("\(Int(confidence * 100))% sure")
                    .font(.caption.bold())
                    .foregroundStyle(confidence >= 0.85 ? AppTheme.mint : AppTheme.warningYellow)
                    .padding(6)
                    .background((confidence >= 0.85 ? AppTheme.mint : AppTheme.warningYellow).opacity(0.14), in: Capsule())
            }
            HStack(spacing: 14) {
                MacroChip(label: "kcal", value: "\(activeCandidate?.calories ?? 0)")
                MacroChip(label: "protein", value: "\(trim(activeCandidate?.proteinG ?? 0))g")
                MacroChip(label: "carbs", value: "\(trim(activeCandidate?.carbsG ?? 0))g")
                MacroChip(label: "fat", value: "\(trim(activeCandidate?.fatG ?? 0))g")
            }
            if needsConfirmation, !parsed.candidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Confidence is low — pick the best match (never auto-filled):")
                        .font(.caption.weight(.semibold))
                    ForEach(Array(parsed.candidates.enumerated()), id: \.offset) { idx, c in
                        Button {
                            candidateIndex = idx + 1
                        } label: {
                            HStack {
                                Text("\(c.title) · \(c.calories) kcal · \(trim(c.proteinG))g protein")
                                    .font(.caption)
                                Spacer()
                                if candidateIndex == idx + 1 {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.mint)
                                }
                            }
                            .padding(8)
                            .background(candidateIndex == idx + 1 ? AppTheme.mint.opacity(0.14) : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button {
                save()
            } label: {
                Label("Confirm & log", systemImage: "checkmark")
            }
            .buttonStyle(BigActionButtonStyle())
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var manualEntryCard: some View {
        VStack(spacing: 10) {
            Text("Manual entry")
                .font(.headline)
            TextField("Meal name", text: $manualTitle)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("Calories", text: $manualCalories).keyboardType(.numberPad)
                TextField("Protein g", text: $manualProtein).keyboardType(.decimalPad)
            }
            Button {
                saveManual()
            } label: {
                Text("Log meal")
            }
            .buttonStyle(BigActionButtonStyle())
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func recognize() async {
        isProcessing = true
        errorMessage = nil
        routeMessage = nil
        parsed = nil
        candidateIndex = 0
        defer { isProcessing = false }

        let onDevice = AppleOnDeviceAI.shared
        let byoProvider = BYOStore.defaultProvider(for: .vision)
        let route = AIRouter.route(for: .vision,
                                   pro: purchaseManager.isPro,
                                   cloudQuota: purchaseManager.hasCloudAI,
                                   byoProvider: byoProvider,
                                   onDeviceAvailable: onDevice.isAvailable,
                                   onDeviceQuotaRemaining: onDevice.quotaRemaining)
        switch route {
        case .byoProvider:
            guard let id = byoProvider, let cfg = BYOStore.configs.first(where: { $0.id == id }) else {
                errorMessage = "Your selected provider isn't ready. Check Settings → AI Engine."
                return
            }
            do {
                let b64 = jpegData!.base64EncodedString()
                let messages: [[String: Any]] = [
                    ["role": "user", "content": [
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]],
                        ["type": "text", "text": "Estimate this meal's macros. Reply ONLY JSON: {\"title\":\"...\",\"calories\":0,\"protein_g\":0,\"carbs_g\":0,\"fat_g\":0,\"confidence\":0.9,\"candidates\":[]}. Never invent precision; lower confidence when unsure."]
                    ]]
                ]
                let json = try await BYOEngine.chat(messages: messages, cfg: cfg, kind: .vision, maxTokens: 8192)
                parsed = ParsedMeal(fromJSON: json)
                routeMessage = "Recognized with your own \(id.displayName) key."
            } catch {
                errorMessage = error.localizedDescription
            }
        case .sharedWorker:
            do {
                parsed = try await GLMCloudService.estimateMeal(jpegData: jpegData!, appTransactionJWS: purchaseManager.lastJWSRepresentation)
                routeMessage = "Cloud recognition."
            } catch {
                errorMessage = error.localizedDescription
            }
        case .onDeviceApple:
            errorMessage = "On-device recognition can't estimate macros from photos yet. Enter manually, or go Pro for cloud vision."
            showManualEntry = true
        case .blocked:
            errorMessage = "Cloud quota reached this month — switched to manual entry (never a dead end)."
            showManualEntry = true
        }
    }

    private func save() {
        guard let c = activeCandidate else { return }
        let meal = MealLog(title: c.title, calories: c.calories, proteinG: c.proteinG, carbsG: c.carbsG, fatG: c.fatG, confidence: confidence, source: "ai")
        modelContext.insert(meal)
        try? modelContext.save()
        dismiss()
    }

    private func saveManual() {
        let meal = MealLog(title: manualTitle.isEmpty ? "Meal" : manualTitle,
                           calories: Int(manualCalories) ?? 0,
                           proteinG: Decimal(string: manualProtein) ?? 0,
                           carbsG: 0, fatG: 0, confidence: 1.0, source: "manual")
        modelContext.insert(meal)
        try? modelContext.save()
        dismiss()
    }

    private func trim(_ d: Decimal) -> String {
        let s = String(format: "%.1f", NSDecimalNumber(decimal: d).doubleValue)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}

struct MacroChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
