import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query(sort: \DoseLog.loggedAt, order: .reverse) private var doseLogs: [DoseLog]
    @Query(sort: \SymptomLog.loggedAt, order: .reverse) private var symptomLogs: [SymptomLog]
    @Query private var goalsList: [GoalSettings]

    @State private var newWeight = ""
    @State private var showPaywall = false
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weightCard
                    symptomCard
                    exportCard
                    AppTheme.disclaimerFooter
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Progress")
            .background(Color(.systemBackground))
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: Binding(get: { pdfURL != nil }, set: { if !$0 { pdfURL = nil } })) {
                if let pdfURL {
                    ActivitySheet(items: [pdfURL])
                }
            }
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight")
                    .font(.headline)
                Spacer()
                if let last = weights.last {
                    Text("\(trim(last.kg)) kg · \(String(format: "%.0f", NSDecimalNumber(decimal: last.kg).doubleValue * 2.20462)) lb")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.mint)
                }
            }
            if weights.count >= 2 {
                Chart(weights) { entry in
                    LineMark(x: .value("Date", entry.date), y: .value("kg", NSDecimalNumber(decimal: entry.kg).doubleValue))
                        .foregroundStyle(AppTheme.mint)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", entry.date), y: .value("kg", NSDecimalNumber(decimal: entry.kg).doubleValue))
                        .foregroundStyle(AppTheme.coral)
                }
                .frame(height: 160)
            } else {
                Text("Log two weights to see your trend line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("Weight kg", text: $newWeight)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Button("Log") {
                    saveWeight()
                }
                .buttonStyle(.borderedProminent)
                .disabled(Decimal(string: newWeight) == nil)
            }
            Text("Weights also sync to HealthKit when enabled in Settings — see the Apple Health (HealthKit) section.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var symptomCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent symptoms")
                .font(.headline)
            if symptomLogs.isEmpty {
                Text("No symptoms logged — great sign. Log how you feel from the Today screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(symptomLogs.prefix(8), id: \.persistentModelID) { s in
                    HStack {
                        Text(s.name)
                        Spacer()
                        Text(String(repeating: "●", count: s.severity) + String(repeating: "○", count: 5 - s.severity))
                            .font(.caption)
                            .foregroundStyle(s.severity >= 4 ? .red : AppTheme.coral)
                        Text(s.loggedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Doctor-ready PDF", systemImage: "doc.richtext.fill")
                .font(.headline)
            Text("One tidy file: every shot, symptom, weight and vial balance with a medical disclaimer on every page.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                if purchaseManager.isPro {
                    exportPDF()
                } else {
                    showPaywall = true
                }
            } label: {
                Label("Export PDF report", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(BigActionButtonStyle())
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private func saveWeight() {
        guard let kg = Decimal(string: newWeight), kg > 20, kg < 400 else { return }
        let entry = WeightEntry(kg: kg)
        modelContext.insert(entry)
        try? modelContext.save()
        newWeight = ""
        let kgDouble = NSDecimalNumber(decimal: kg).doubleValue
        Task {
            _ = await HealthKitService.shared.writeWeight(kg: kgDouble)
        }
    }

    private func exportPDF() {
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let data = PDFReportService.generateReport(
            doseLogs: Array(doseLogs),
            symptomLogs: Array(symptomLogs),
            weightEntries: Array(weights),
            vials: vialsSnapshot(),
            goalSettings: goalsList.first,
            startDate: start,
            endDate: Date()
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ShotJoy-Report.pdf")
        try? data.write(to: url)
        pdfURL = url
    }

    @Query private var vialsQuery: [Vial]
    private func vialsSnapshot() -> [Vial] { vialsQuery }

    private func trim(_ d: Decimal) -> String {
        String(format: "%.1f", NSDecimalNumber(decimal: d).doubleValue)
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
