import SwiftUI
import SwiftData

struct MedsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var compounds: [Compound]
    @Query private var vials: [Vial]
    @Query private var doseLogs: [DoseLog]
    @State private var showCalculator = false
    @State private var showVialSnap = false
    @State private var showAddCompound = false
    @State private var showPaywall = false
    @State private var showTitration = false
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    quickTools
                    vialsSection
                    compoundsSection
                    AppTheme.disclaimerFooter
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Meds")
            .background(Color(.systemBackground))
            .sheet(isPresented: $showCalculator) { NavigationStack { CalculatorView() } }
            .sheet(isPresented: $showVialSnap) { VialSnapView() }
            .sheet(isPresented: $showAddCompound) { AddCompoundSheet() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showTitration) { NavigationStack { TitrationView() } }
        }
    }

    private var quickTools: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "DrawGuard", icon: "function") { showCalculator = true }
            QuickActionButton(title: "Scan vial", icon: "camera.viewfinder") { showVialSnap = true }
            Button {
                if purchaseManager.isPro {
                    showTitration = true
                } else {
                    showPaywall = true
                }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(AppTheme.coral)
                    Text("Titration")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Titration mode, Pro feature")
        }
    }

    private var vialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vials & inventory")
                    .font(.headline)
                Spacer()
                Button {
                    showVialSnap = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                }
            }
            if vials.isEmpty {
                Text("No vials yet. Scan a label or add one manually to start inventory tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(vials, id: \.persistentModelID) { vial in
                VialRow(vial: vial, doseLogs: doseLogs)
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var compoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Compounds")
                    .font(.headline)
                Spacer()
                Button {
                    showAddCompound = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                }
            }
            if compounds.isEmpty {
                Text("Compounds you track appear here (pens and peptides).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(compounds, id: \.persistentModelID) { compound in
                HStack {
                    Image(systemName: compound.kind == "glp1" ? "syringe.fill" : "testtube.2")
                        .foregroundStyle(AppTheme.coral)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(compound.name).font(.subheadline.weight(.semibold))
                        Text("\(compound.kind == "glp1" ? "GLP-1" : "Peptide") · half-life ~\(Int(compound.halfLifeHours))h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if compound.isPreset {
                        Text("preset")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            NavigationLink("Browse 100+ compound library") {
                CompoundLibraryView()
            }
            .font(.subheadline.bold())
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct VialRow: View {
    let vial: Vial
    let doseLogs: [DoseLog]

    private var restockDate: Date? {
        let remaining = NSDecimalNumber(decimal: vial.remainingMG).doubleValue
        guard remaining > 0 else { return Date() }
        let doses = vial.dosesRemaining
        guard doses > 0 else { return Date() }
        let logs = doseLogs.filter { $0.compoundName == vial.compoundName }.prefix(5)
        guard logs.count >= 2 else { return nil }
        let span = logs.first!.loggedAt.timeIntervalSince(logs.last!.loggedAt)
        let perDose = span / Double(logs.count - 1)
        return Date().addingTimeInterval(perDose * Double(doses))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vial.compoundName).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(vial.dosesRemaining) doses left")
                    .font(.caption.bold())
                    .foregroundStyle(vial.dosesRemaining <= 2 ? AppTheme.warningYellow : AppTheme.mint)
            }
            ProgressView(value: Double(truncating: (vial.remainingMG / max(vial.massMG, 0.0001)) as NSDecimalNumber))
                .tint(vial.dosesRemaining <= 2 ? AppTheme.warningYellow : AppTheme.mint)
            HStack {
                Text("\(trim(vial.remainingMG))/\(trim(vial.massMG)) mg · \(trim(vial.concentrationMCGPerML)) mcg/mL · \(SyringeType(rawValue: vial.syringeType)?.label ?? vial.syringeType)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let restockDate {
                    Text("Reorder by \(restockDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func trim(_ d: Decimal) -> String {
        let s = String(format: "%.1f", NSDecimalNumber(decimal: d).doubleValue)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}

struct AddCompoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var kind = "peptide"
    @State private var halfLife = "24"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Compound name", text: $name)
                Picker("Type", selection: $kind) {
                    Text("Peptide").tag("peptide")
                    Text("GLP-1").tag("glp1")
                    Text("Blend").tag("blend")
                }
                TextField("Half-life (hours)", text: $halfLife)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("New compound")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let compound = Compound(name: name, kind: kind, halfLifeHours: Double(halfLife) ?? 24, isPreset: false)
                        modelContext.insert(compound)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct CompoundLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var added: Set<String> = []

    var body: some View {
        List {
            ForEach(CompoundPresets.search(search), id: \.name) { preset in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name).font(.subheadline.weight(.medium))
                        Text("\(preset.kind.uppercased()) · half-life ~\(preset.halfLifeHours < 1 ? String(format: "%.1f", preset.halfLifeHours) : String(Int(preset.halfLifeHours)))h")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if added.contains(preset.name) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.mint)
                    } else {
                        Button("Track") {
                            let compound = Compound(name: preset.name, kind: preset.kind, halfLifeHours: preset.halfLifeHours, isPreset: false)
                            modelContext.insert(compound)
                            try? modelContext.save()
                            added.insert(preset.name)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search 100+ compounds")
        .navigationTitle("Compound library")
    }
}
