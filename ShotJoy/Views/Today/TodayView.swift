import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DoseLog.loggedAt, order: .reverse) private var doseLogs: [DoseLog]
    @Query(sort: \MealLog.loggedAt, order: .reverse) private var mealLogs: [MealLog]
    @Query private var compounds: [Compound]
    @Query private var vials: [Vial]
    @Query private var goalsList: [GoalSettings]

    @State private var showLogSheet = false
    @State private var showSymptomSheet = false
    @State private var showMealSnap = false
    @State private var showCalculator = false
    @State private var showCelebration = false
    @State private var showShareCard = false
    @State private var todayProtein: Decimal = 0

    private var goals: GoalSettings? { goalsList.first }
    private var isShotDay: Bool {
        guard let goals, goals.reminderEnabled else { return false }
        return Calendar.current.component(.weekday, from: Date()) == goals.reminderWeekday
    }
    private var lastDose: DoseLog? { doseLogs.first }
    private var streak: Int { StreakCalculator.streak(from: doseLogs, cadenceDays: goals?.cadenceDays ?? 7) }
    private var weekNumber: Int {
        guard let first = goals?.firstShotDate ?? doseLogs.last?.loggedAt else { return 1 }
        return max(1, Int(Date.now.timeIntervalSince(first) / (7 * 86400)) + 1)
    }
    private var totalLossLB: Double? {
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\WeightEntry.date)])
        guard let all = try? modelContext.fetch(descriptor), all.count >= 2, let f = all.first, let l = all.last else { return nil }
        let delta = NSDecimalNumber(decimal: f.kg - l.kg).doubleValue * 2.20462
        return delta
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isShotDay, let goals {
                        ShotDayCard(goals: goals, doseLogs: doseLogs, vials: vials) {
                            showLogSheet = true
                        }
                    } else {
                        plasmaCard
                    }
                    proteinCard
                    quickActions
                    restockCard
                    AppTheme.disclaimerFooter
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Today")
            .background(Color(.systemBackground))
            .overlay {
                if showCelebration {
                    ConfettiView()
                }
            }
            .sheet(isPresented: $showLogSheet, onDismiss: { showShareCard = true }) {
                LogShotSheet(vials: vials, doseLogs: doseLogs, goals: goals) {
                    showCelebration = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showCelebration = false }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showSymptomSheet) {
                SymptomLogSheet(lastDose: lastDose)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showMealSnap) {
                MealSnapView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showCalculator) {
                NavigationStack { CalculatorView() }
            }
            .sheet(isPresented: $showShareCard) {
                ShareCardSheet(weekNumber: weekNumber, streak: streak, totalLossLB: totalLossLB, compoundName: lastDose?.compoundName ?? "Your shot")
            }
            .task { await refreshProtein() }
        }
    }

    private var plasmaCard: some View {
        let halfLife = compoundHalfLife
        let level = PlasmaCurve.currentLevel(doseLogs: doseLogs, halfLifeHours: halfLife)
        let points = PlasmaCurve.curvePoints(halfLifeHours: halfLife, cadenceDays: goals?.cadenceDays ?? 7)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Drug level", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                if let level {
                    Text("\(Int(level))% · \(PlasmaCurve.phaseLabel(percent: level))")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.mint)
                }
            }
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("Hours", p.x), y: .value("Level", p.y))
                        .foregroundStyle(AppTheme.mint)
                        .interpolationMethod(.catmullRom)
                }
                if let last = lastDose {
                    let hours = Date.now.timeIntervalSince(last.loggedAt) / 3600
                    if hours >= 0, let level {
                        PointMark(x: .value("Hours", hours), y: .value("Level", level))
                            .foregroundStyle(AppTheme.coral)
                            .symbolSize(60)
                    }
                }
            }
            .chartYScale(domain: 0...110)
            .frame(height: 120)
            Text("Educational visualization of \(Int(compoundHalfLife))h half-life — not for dosing decisions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private var compoundHalfLife: Double {
        if let name = lastDose?.compoundName,
           let c = compounds.first(where: { $0.name == name }) {
            return c.halfLifeHours
        }
        return CompoundPresets.all.first { $0.name == (lastDose?.compoundName ?? "") }?.halfLifeHours ?? 168
    }

    private var proteinCard: some View {
        let target = goals?.proteinTargetG ?? 100
        let pct = min(1.0, NSDecimalNumber(decimal: todayProtein).doubleValue / max(NSDecimalNumber(decimal: target).doubleValue, 1))
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(AppTheme.mint.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(AppTheme.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(pct * 100))%")
                    .font(.headline)
            }
            .frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 4) {
                Text("Protein today")
                    .font(.headline)
                Text("\(trim(todayProtein))g / \(trim(target))g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if pct < 1 {
                    Text("Protein helps protect muscle on GLP-1. Log dinner to close the ring.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "Meal photo", icon: "camera.fill") { showMealSnap = true }
            QuickActionButton(title: "Symptom", icon: "stethoscope") { showSymptomSheet = true }
            QuickActionButton(title: "Calculator", icon: "function") { showCalculator = true }
        }
    }

    private var restockCard: some View {
        Group {
            if let v = vials.first {
                let remaining = NSDecimalNumber(decimal: v.remainingMG).doubleValue
                HStack {
                    Label("\(v.compoundName): \(Int(remaining * 1000)) mcg left", systemImage: "vial.fill")
                        .font(.subheadline)
                    Spacer()
                    Text("\(v.dosesRemaining) doses")
                        .font(.subheadline.bold())
                        .foregroundStyle(v.dosesRemaining <= 2 ? AppTheme.warningYellow : AppTheme.mint)
                }
                .padding()
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func refreshProtein() async {
        let start = Calendar.current.startOfDay(for: Date())
        todayProtein = mealLogs.filter { $0.loggedAt >= start }.reduce(Decimal(0)) { $0 + $1.proteinG }
    }

    private func trim(_ d: Decimal) -> String {
        let s = String(format: "%.1f", NSDecimalNumber(decimal: d).doubleValue)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}

enum StreakCalculator {
    static func streak(from logs: [DoseLog], cadenceDays: Int) -> Int {
        let sorted = logs.map { $0.loggedAt }.sorted(by: >)
        guard !sorted.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 1
        var cursor = sorted[0]
        for date in sorted.dropFirst() {
            let diff = calendar.dateComponents([.day], from: date, to: cursor).day ?? 0
            if diff <= cadenceDays {
                streak += 1
                cursor = date
            } else {
                break
            }
        }
        return streak
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppTheme.coral)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct ShotDayCard: View {
    let goals: GoalSettings
    let doseLogs: [DoseLog]
    let vials: [Vial]
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Shot Day!", systemImage: "party.popper.fill")
                    .font(.title2.bold())
                Spacer()
                Text("Week ritual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let (site, suggested) = recommended
            Text("2.5mg-style plan · \(BodySites.label(for: site))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if suggested {
                Text("Suggested site based on your rotation — change it on the body map.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mint)
            }
            Button {
                onLog()
            } label: {
                Label("Record my shot 🎯", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(BigActionButtonStyle())
            .accessibilityHint("Opens the pre-filled shot logging sheet")
        }
        .padding()
        .background(AppTheme.coral.opacity(0.14), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.coral.opacity(0.4), lineWidth: 1))
    }

    private var recommended: (site: String, suggested: Bool) {
        let site = BodySites.recommendedNext(recent: doseLogs)
        return (site, true)
    }
}
