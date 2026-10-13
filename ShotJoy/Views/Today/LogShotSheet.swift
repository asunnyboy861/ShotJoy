import SwiftUI
import SwiftData

struct LogShotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var compoundRecords: [Compound]
    @Query(sort: \SymptomLog.loggedAt, order: .reverse) private var recentSymptoms: [SymptomLog]
    let vials: [Vial]
    let doseLogs: [DoseLog]
    let goals: GoalSettings?
    let onSuccess: () -> Void

    @State private var selectedVialID: String?
    @State private var penCompoundName = ""
    @State private var doseMCGText = ""
    @State private var unitsText = ""
    @State private var syringeType: SyringeType = .u100
    @State private var site = BodySites.all[0].id
    @State private var backfillDate: Date? = nil
    @State private var showBackfill = false
    @State private var result: DoseResult?
    @State private var isPen = false
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    if !penCompounds.isEmpty {
                        Picker("GLP-1 pen", selection: $penCompoundName) {
                            ForEach(penCompounds, id: \.self) { Text($0).tag($0) }
                        }
                        .onChange(of: penCompoundName) { _, _ in isPen = true }
                    }
                    if !vials.isEmpty {
                        Picker("Vial", selection: $selectedVialID) {
                            Text("None").tag(String?.none)
                            ForEach(vials, id: \.persistentModelID) { vial in
                                Text("\(vial.compoundName) · \(trim(vial.massMG))mg").tag(String?.some(vial.id.uuidString))
                            }
                        }
                        .onChange(of: selectedVialID) { _, newValue in
                            if let id = newValue, let vial = vials.first(where: { $0.id.uuidString == id }) {
                                isPen = false
                                let mass = vial.massMG
                                let water = vial.bacWaterML
                                syringeType = SyringeType(rawValue: vial.syringeType) ?? .u100
                                let defaultDose = goals?.typicalDoseMCG ?? 0
                                if defaultDose > 0 {
                                    doseMCGText = trim(defaultDose)
                                    recalc(mass: mass, water: water)
                                }
                            }
                        }
                    }
                }
                Section("Dose") {
                    TextField("Dose (mcg) — your prescribed amount", text: $doseMCGText)
                        .keyboardType(.decimalPad)
                        .onChange(of: doseMCGText) { _, _ in recalc() }
                    if !isPen {
                        TextField("Units drawn", text: $unitsText)
                            .keyboardType(.decimalPad)
                        Picker("Syringe", selection: $syringeType) {
                            ForEach(SyringeType.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: syringeType) { _, _ in recalc() }
                    }
                }
                if let result {
                    Section("Safety check") {
                        DrawGuardResultCard(result: result)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                Section("Injection site") {
                    Picker("Site", selection: $site) {
                        ForEach(BodySites.all, id: \.id) { s in
                            Text(s.label).tag(s.id)
                        }
                    }
                    NavigationLink("Open body map") {
                        BodyMapView(selectedSite: $site, doseLogs: doseLogs)
                    }
                }
                Section {
                    Toggle("Log for a past day", isOn: $showBackfill.animation())
                    if showBackfill {
                        DatePicker("Day", selection: Binding(get: { backfillDate ?? Date() }, set: { backfillDate = $0 }), displayedComponents: .date)
                    }
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("Missed a day? Backfill it — ShotJoy never punishes.")
                }
            }
            .navigationTitle("Record my shot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log ✅") { log() }
                        .disabled(!canLog)
                }
            }
            .onAppear {
                doseMCGText = goals.map { trim($0.typicalDoseMCG) } ?? ""
                if penCompounds.isEmpty && vials.isEmpty {
                    isPen = true
                    penCompoundName = "Custom"
                } else if penCompounds.isEmpty {
                    isPen = false
                    selectedVialID = vials.first?.id.uuidString
                } else {
                    isPen = true
                    penCompoundName = penCompounds[0]
                }
            }
        }
    }

    private var penCompounds: [String] {
        let tracked = compoundRecords.filter { $0.kind == "glp1" }.map { $0.name }
        if !tracked.isEmpty { return tracked }
        return CompoundPresets.all.filter { $0.kind == "glp1" }.prefix(6).map { $0.name }
    }

    private var canLog: Bool {
        guard let dose = Decimal(string: doseMCGText), dose > 0 else { return false }
        if !isPen {
            guard selectedVial != nil else { return false }
            guard let r = result, !r.warnings.contains(where: { w in if case .unrealisticInput = w { return true }; return false }) else { return false }
        }
        return true
    }

    private var selectedVial: Vial? {
        guard let id = selectedVialID else { return nil }
        return vials.first { $0.id.uuidString == id }
    }

    private func recalc(mass: Decimal? = nil, water: Decimal? = nil) {
        guard let vial = selectedVial ?? (mass != nil ? Vial(compoundName: "", massMG: mass!, bacWaterML: water!, remainingMG: mass!, syringeType: syringeType.rawValue) : nil) else { return }
        guard let dose = Decimal(string: doseMCGText), dose > 0 else { result = nil; return }
        let r = DrawGuard.calculate(Reconstitution(vialMassMG: vial.massMG, bacWaterML: vial.bacWaterML, syringeType: syringeType), doseMCG: dose)
        result = r
        if !unitsText.isEmpty { return }
        unitsText = trim(r.units)
    }

    private func log() {
        guard let dose = Decimal(string: doseMCGText) else { return }
        let loggedAt = showBackfill ? (backfillDate ?? Date()) : Date()
        let name = isPen ? penCompoundName : (selectedVial?.compoundName ?? "Unknown")
        let unitsValue = isPen ? Decimal(0) : (Decimal(string: unitsText) ?? result?.units ?? 0)
        let entry = DoseLog(compoundName: name, doseMCG: dose, units: unitsValue, syringe: isPen ? "pen" : syringeType.rawValue, site: site, loggedAt: loggedAt, notes: notes, isBackfill: showBackfill)
        modelContext.insert(entry)
        if let symptom = recentSymptoms.first {
            symptom.doseRef = entry
        }
        if let vial = selectedVial, !isPen {
            vial.remainingMG = max(vial.remainingMG - dose / 1000, 0)
        }
        if let goals {
            if goals.firstShotDate == nil { goals.firstShotDate = loggedAt }
            if goals.typicalDoseMCG == 0 { goals.typicalDoseMCG = dose }
        }
        try? modelContext.save()
        onSuccess()
        dismiss()
    }

    private func trim(_ d: Decimal) -> String {
        let s = String(format: "%.1f", NSDecimalNumber(decimal: d).doubleValue)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}

struct SymptomLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let lastDose: DoseLog?

    @State private var search = ""
    @State private var selected: String?
    @State private var severity: Double = 2

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let dose = lastDose {
                    Label("Linked to your \(dose.compoundName) shot", systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("Search symptoms", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                        ForEach(SymptomPresets.all.filter { $0.localizedCaseInsensitiveContains(search) }, id: \.self) { name in
                            Button {
                                selected = name
                            } label: {
                                Text(name)
                                    .font(.subheadline)
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(selected == name ? AppTheme.coral : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(selected == name ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                VStack(spacing: 8) {
                    Text("Severity: \(Int(severity))/5")
                        .font(.headline)
                    Slider(value: $severity, in: 1...5, step: 1)
                        .tint(AppTheme.coral)
                        .padding(.horizontal)
                }
                Button {
                    save()
                } label: {
                    Text("Log symptom")
                }
                .buttonStyle(BigActionButtonStyle())
                .padding()
                .disabled(selected == nil)
            }
            .navigationTitle("How do you feel?")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        guard let name = selected else { return }
        let log = SymptomLog(name: name, severity: Int(severity))
        modelContext.insert(log)
        log.doseRef = lastDose
        try? modelContext.save()
        dismiss()
    }
}

struct ShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let weekNumber: Int
    let streak: Int
    let totalLossLB: Double?
    let compoundName: String

    @State private var rendered: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let rendered {
                    Image(uiImage: rendered)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 460)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(radius: 10)
                }
                ShareLink(item: Image(uiImage: rendered ?? UIImage()), preview: SharePreview("Shot Day ✅ Week \(weekNumber)", image: Image(uiImage: rendered ?? UIImage()))) {
                    Label("Share the win", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(BigActionButtonStyle())
                Button("Save to Photos") {
                    if let rendered {
                        UIImageWriteToSavedPhotosAlbum(rendered, nil, nil, nil)
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .navigationTitle("Victory card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .onAppear {
                rendered = ShareCardRenderer.render(weekNumber: weekNumber, streak: streak, totalLossLB: totalLossLB, compoundName: compoundName)
            }
        }
    }
}
