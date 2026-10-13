import SwiftUI
import SwiftData

struct CalculatorView: View {
    @State private var vialMassText = "5"
    @State private var waterText = "2"
    @State private var doseText = "250"
    @State private var syringeType: SyringeType = .u100
    @State private var blendMode = false
    @State private var blendMass2Text = ""
    @State private var blendName2 = "Second compound"

    private var result: DoseResult? {
        guard let mass = Decimal(string: vialMassText),
              let water = Decimal(string: waterText),
              let dose = Decimal(string: doseText) else { return nil }
        return DrawGuard.calculate(Reconstitution(vialMassMG: mass, bacWaterML: water, syringeType: syringeType), doseMCG: dose)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unit conversion for your own prescribed dose")
                        .font(.headline)
                    Text("ShotJoy does the math only — it never suggests doses. Enter exactly what your prescriber told you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    LabeledField(label: "Vial total (mg)", text: $vialMassText)
                    LabeledField(label: "BAC water (mL)", text: $waterText)
                    LabeledField(label: "Your prescribed dose (mcg)", text: $doseText)
                    Picker("Syringe", selection: $syringeType) {
                        ForEach(SyringeType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Blend vial (2 compounds)", isOn: $blendMode)
                    if blendMode {
                        LabeledField(label: "Second compound total (mg)", text: $blendMass2Text)
                        LabeledField(label: "Second compound name", text: $blendName2)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))

                if blendMode, let m1 = Decimal(string: vialMassText), let m2 = Decimal(string: blendMass2Text), let water = Decimal(string: waterText), let dose = Decimal(string: doseText), m2 > 0 {
                    BlendResultCard(components: [("Compound 1", m1), (blendName2, m2)], bacWaterML: water, doseMCGTotal: dose, syringe: syringeType)
                } else if let result {
                    DrawGuardResultCard(result: result)
                }

                if let units = result?.units, let dose = Decimal(string: doseText), let mass = Decimal(string: vialMassText), units > 0, units < 5 {
                    ReconstituteSuggestions(vialMG: mass, doseMCG: dose)
                }

                AppTheme.disclaimerFooter
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("DrawGuard")
        .background(Color(.systemBackground))
    }
}

struct LabeledField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
            TextField(label, text: $text)
                .keyboardType(.decimalPad)
                .padding(12)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityElement(children: .combine)
    }
}

struct ReconstituteSuggestions: View {
    let vialMG: Decimal
    let doseMCG: Decimal

    private var suggestions: [Decimal] {
        DrawGuard.suggestedWaterML(vialMG: vialMG, doseMCG: doseMCG)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Re-constitute suggestions", systemImage: "waterbottle.fill")
                .font(.subheadline.bold())
            Text("Add this much BAC water so your \(trim(doseMCG)) mcg dose lands exactly on a syringe mark:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, ml in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.mint)
                    Text("\(trim(ml)) mL water → exact mark")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(8)
                .background(AppTheme.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private func trim(_ d: Decimal) -> String {
        let s = String(format: "%.2f", NSDecimalNumber(decimal: d).doubleValue)
        return s.hasSuffix(".00") ? String(s.dropLast(3)) : (s.hasSuffix("0") ? String(s.dropLast(1)) : s)
    }
}

struct BlendResultCard: View {
    let components: [(name: String, massMG: Decimal)]
    let bacWaterML: Decimal
    let doseMCGTotal: Decimal
    let syringe: SyringeType

    private var computed: (results: [(name: String, units: Decimal, share: Double)], totalUnits: Decimal, warnings: [DoseWarning]) {
        DrawGuard.calculateBlend(components: components, bacWaterML: bacWaterML, doseMCGTotal: doseMCGTotal, syringe: syringe)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(trim(computed.totalUnits))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.mint)
                Text("units total")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ForEach(Array(computed.results.enumerated()), id: \.offset) { _, item in
                HStack {
                    Circle().fill(AppTheme.coral.opacity(0.7)).frame(width: 8, height: 8)
                    Text("\(item.name) — \(Int(item.share * 100))% of blend")
                        .font(.subheadline)
                    Spacer()
                    Text("\(trim(item.units)) units")
                        .font(.subheadline.bold())
                }
            }
            Text("Per-compound itemization with total conservation check.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            AppTheme.disclaimerFooter
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private func trim(_ d: Decimal) -> String {
        String(format: "%.1f", NSDecimalNumber(decimal: d).doubleValue)
    }
}
