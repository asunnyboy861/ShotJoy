import SwiftUI
import SwiftData
import UserNotifications

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step = 0
    @State private var selectedPreset: CompoundPreset?
    @State private var vialMassMGText = ""
    @State private var bacWaterMLText = "2"
    @State private var doseMCGText = "250"
    @State private var syringeType: SyringeType = .u100
    @State private var reminderEnabled = true
    @State private var demoResult: DoseResult?

    var body: some View {
        NavigationStack {
            VStack {
                ProgressView(value: Double(step + 1), total: 5)
                    .tint(AppTheme.coral)
                    .padding(.horizontal)
                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    drugStep.tag(1)
                    formStep.tag(2)
                    previewStep.tag(3)
                    finalStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemBackground))
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "syringe.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppTheme.coral)
            Text("Every shot, a win.")
                .font(.largeTitle.bold())
            Text("Track GLP-1 pens and peptide vials, do the math safely, and celebrate every Shot Day.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button { withAnimation { step = 1 } } label: {
                Text("Get started")
            }
            .buttonStyle(BigActionButtonStyle())
            .padding()
            AppTheme.disclaimerFooter.padding(.bottom, 8)
        }
    }

    private var drugStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("What are you tracking?")
                    .font(.title.bold())
                    .padding(.top)
                Text("Pick a common starting point — you can add more later.")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(favorites, id: \.name) { preset in
                        PresetCard(preset: preset, selected: selectedPreset?.name == preset.name) {
                            selectedPreset = preset
                            if preset.kind == "glp1" {
                                doseMCGText = preset.name.contains("Tirzepatide") ? "2500" : "250"
                            }
                        }
                    }
                }
                ForEach(CompoundPresets.search("").filter { preset in !favorites.contains { $0.name == preset.name } && preset.kind != "blend" }, id: \.name) { preset in
                    Button {
                        selectedPreset = preset
                    } label: {
                        HStack {
                            Text(preset.name)
                            Spacer()
                            if selectedPreset?.name == preset.name {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.mint)
                            }
                        }
                        .padding(14)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation { step = selectedPreset?.kind == "glp1" ? 3 : 2 }
            } label: {
                Text(selectedPreset == nil ? "Select one to continue" : "Continue")
            }
            .buttonStyle(BigActionButtonStyle())
            .disabled(selectedPreset == nil)
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private var formStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Set up your vial")
                    .font(.title.bold())
                    .padding(.top)
                Text("Three fields — or scan the label later in Meds.")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total in vial (mg)")
                    TextField("e.g. 5", text: $vialMassMGText)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("BAC water (mL)")
                    TextField("e.g. 2", text: $bacWaterMLText)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Target dose (mcg)")
                    TextField("e.g. 250", text: $doseMCGText)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Syringe")
                    Picker("Syringe", selection: $syringeType) {
                        ForEach(SyringeType.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if let r = demoResult {
                    DrawGuardResultCard(result: r)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                recalcDemo()
                withAnimation { step = 3 }
            } label: {
                Text("Check my math")
            }
            .buttonStyle(BigActionButtonStyle())
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private var previewStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.mint)
            Text("Next shot: Shot Day")
                .font(.title.bold())
            Text("We'll remind you with a friendly nudge. Missed a day? You can always backfill — ShotJoy never punishes.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Toggle("Enable Shot Day reminders", isOn: $reminderEnabled)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                withAnimation { step = 4 }
            } label: {
                Text("Continue")
            }
            .buttonStyle(BigActionButtonStyle())
            .padding()
        }
    }

    private var finalStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.coral)
            Text("You're all set")
                .font(.title.bold())
            Text("One more tap on the Today screen and Shot #1 is in the books. 🔥")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button {
                Task { await finish() }
            } label: {
                Text("Start tracking")
            }
            .buttonStyle(BigActionButtonStyle())
            .padding()
        }
    }

    private var favorites: [CompoundPreset] {
        ["Semaglutide (Ozempic)", "Tirzepatide (Zepbound)", "Retatrutide", "BPC-157", "Tirzepatide (Mounjaro)", "Semaglutide (Wegovy)"]
            .compactMap { name in CompoundPresets.all.first { $0.name == name } }
    }

    private func recalcDemo() {
        let mass = Decimal(string: vialMassMGText) ?? 5
        let water = Decimal(string: bacWaterMLText) ?? 2
        let dose = Decimal(string: doseMCGText) ?? 250
        demoResult = DrawGuard.calculate(Reconstitution(vialMassMG: mass, bacWaterML: water, syringeType: syringeType), doseMCG: dose)
    }

    private func finish() async {
        if let preset = selectedPreset {
            let compound = Compound(name: preset.name, kind: preset.kind, halfLifeHours: preset.halfLifeHours, isPreset: false)
            modelContext.insert(compound)
            if preset.kind != "glp1", let mass = Decimal(string: vialMassMGText) {
                let water = Decimal(string: bacWaterMLText) ?? 2
                let vial = Vial(compoundName: preset.name, massMG: mass, bacWaterML: water, remainingMG: mass, syringeType: syringeType.rawValue, reconstitutedAt: Date())
                vial.compound = compound
                modelContext.insert(vial)
            }
        }
        let goals = GoalSettings()
        goals.typicalDoseMCG = Decimal(string: doseMCGText) ?? 250
        goals.reminderEnabled = reminderEnabled
        goals.reminderWeekday = 6
        modelContext.insert(goals)
        try? modelContext.save()

        if reminderEnabled {
            let granted = await NotificationService.requestPermission()
            if granted {
                await NotificationService.scheduleShotDay(weekday: 6, hour: 9, minute: 0)
            }
        }
        hasCompletedOnboarding = true
    }
}

private struct PresetCard: View {
    let preset: CompoundPreset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: preset.kind == "glp1" ? "syringe.fill" : "testtube.2")
                    .font(.title2)
                    .foregroundStyle(selected ? .white : AppTheme.coral)
                Text(preset.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? .white : .primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? AppTheme.coral : AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.name), \(selected ? "selected" : "not selected")")
    }
}
