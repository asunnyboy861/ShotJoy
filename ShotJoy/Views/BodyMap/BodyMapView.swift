import SwiftUI
import SwiftData

struct BodyMapView: View {
    @Binding var selectedSite: String
    let doseLogs: [DoseLog]
    @State private var pulse = false

    private var recommended: String { BodySites.recommendedNext(recent: doseLogs) }

    private func heatColor(for siteID: String) -> Color {
        let recent = doseLogs.filter { $0.site == siteID }
        guard let last = recent.map({ $0.loggedAt }).max() else { return .gray.opacity(0.3) }
        let days = Date.now.timeIntervalSince(last) / 86400
        switch days {
        case ..<7: return AppTheme.coral
        case ..<14: return AppTheme.coral.opacity(0.55)
        case ..<28: return AppTheme.coral.opacity(0.28)
        default: return .gray.opacity(0.3)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Image(systemName: "figure.standing")
                        .font(.system(size: 120))
                        .foregroundStyle(.secondary)
                    Text("Tap where you injected (or plan to)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .overlay {
                    GeometryReader { geo in
                        ForEach(BodySites.all, id: \.id) { site in
                            let pos = position(for: site.id, in: geo.size)
                            ZStack {
                                Circle()
                                    .fill(heatColor(for: site.id))
                                    .frame(width: 22, height: 22)
                                if site.id == recommended {
                                    Circle()
                                        .stroke(AppTheme.mint, lineWidth: 2)
                                        .frame(width: pulse ? 34 : 26, height: pulse ? 34 : 26)
                                        .opacity(pulse ? 0.3 : 1)
                                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                                }
                                if site.id == selectedSite {
                                    Circle().strokeBorder(.primary, lineWidth: 2).frame(width: 30, height: 30)
                                }
                            }
                            .position(pos)
                            .onTapGesture { selectedSite = site.id }
                            .accessibilityLabel("\(site.label) injection site")
                            .accessibilityAddTraits(site.id == selectedSite ? .isSelected : [])
                        }
                    }
                    .frame(height: 260)
                }
                .frame(height: 280)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Last injections")
                        .font(.headline)
                    ForEach(doseLogs.filter { !$0.site.isEmpty }.prefix(6), id: \.persistentModelID) { log in
                        HStack {
                            Circle().fill(heatColor(for: log.site)).frame(width: 10, height: 10)
                            Text(BodySites.label(for: log.site))
                            Spacer()
                            Text(log.loggedAt.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .font(.subheadline)
                    }
                    if doseLogs.count >= 6 {
                        siteInsight
                    }
                }
                .padding()
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Body map")
        .background(Color(.systemBackground))
        .onAppear { pulse = true }
    }

    @ViewBuilder
    private var siteInsight: some View {
        let abdomen = doseLogs.filter { $0.site.contains("abdomen") }
        let other = doseLogs.filter { !$0.site.contains("abdomen") }
        if abdomen.count >= 3, other.count >= 3 {
            let abdNausea = nauseaAverage(for: abdomen)
            let otherNausea = nauseaAverage(for: other)
            if let a = abdNausea, let o = otherNausea, a < o {
                let pct = Int((1 - a / o) * 100)
                if pct > 0 {
                    Label("Your nausea scores run about \(pct)% lower with abdomen shots (based on your own logs — informational, not medical advice).", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mint)
                }
            }
        }
    }

    private func nauseaAverage(for logs: [DoseLog]) -> Double? {
        let severities = logs.compactMap { log in log.symptoms?.filter { $0.name == "Nausea" }.map { Double($0.severity) } }.flatMap { $0 }
        guard !severities.isEmpty else { return nil }
        return severities.reduce(0, +) / Double(severities.count)
    }

    private func position(for siteID: String, in size: CGSize) -> CGPoint {
        switch siteID {
        case "abdomen-UL": return CGPoint(x: size.width * 0.42, y: size.height * 0.42)
        case "abdomen-UR": return CGPoint(x: size.width * 0.58, y: size.height * 0.42)
        case "abdomen-LL": return CGPoint(x: size.width * 0.42, y: size.height * 0.54)
        case "abdomen-LR": return CGPoint(x: size.width * 0.58, y: size.height * 0.54)
        case "thigh-L-outer": return CGPoint(x: size.width * 0.36, y: size.height * 0.86)
        case "thigh-R-outer": return CGPoint(x: size.width * 0.64, y: size.height * 0.86)
        case "arm-L-back": return CGPoint(x: size.width * 0.28, y: size.height * 0.28)
        case "arm-R-back": return CGPoint(x: size.width * 0.72, y: size.height * 0.28)
        default: return CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }
}
