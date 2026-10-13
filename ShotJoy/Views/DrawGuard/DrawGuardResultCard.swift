import SwiftUI
import SwiftData
import Charts

struct DrawGuardResultCard: View {
    let result: DoseResult

    private var hasBlocking: Bool {
        result.warnings.contains { w in
            if case .unrealisticInput = w { return true }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(trimUnits(result.units))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(hasBlocking ? AppTheme.warningYellow : AppTheme.mint)
                Text("units")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if !hasBlocking {
                    Label("Safe zone", systemImage: "checkmark.shield.fill")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.mint)
                        .padding(8)
                        .background(AppTheme.mint.opacity(0.15), in: Capsule())
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(trimUnits(result.units)) units \(hasBlocking ? "needs attention" : "in safe zone")")

            VStack(alignment: .leading, spacing: 6) {
                Label("\(trimNum(result.resultVolumeML)) mL to draw", systemImage: "drop.fill")
                Label("Concentration \(trimNum(result.concentrationMCGPerML)) mcg/mL", systemImage: "function")
                Label("\(result.dosesRemaining) doses remaining in vial", systemImage: "vial")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            ForEach(Array(result.warnings.enumerated()), id: \.offset) { _, warning in
                WarningRow(warning: warning)
            }

            HStack {
                Text("Unit conversion for your prescribed dose")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            AppTheme.disclaimerFooter
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var resultVolumeML: Decimal { result.volumeML }

    private func trimUnits(_ value: Decimal) -> String {
        let n = NSDecimalNumber(decimal: value)
        let formatted = String(format: "%.1f", n.doubleValue)
        return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
    }

    private func trimNum(_ value: Decimal) -> String {
        String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }
}

private extension DoseResult {
    var resultVolumeML: Decimal { volumeML }
}

struct WarningRow: View {
    let warning: DoseWarning

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch warning {
            case .drawTooSmall(let units, let suggestions):
                WarningCard(title: "Tiny draw — accuracy risk",
                            body: "\(trim(units)) units is below the reliable minimum of 5 units (measurement error exceeds 10%).", tone: .warn)
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add one of these BAC water amounts to land exactly on a mark:")
                            .font(.caption.weight(.semibold))
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { _, ml in
                            Text("• \(trim(ml)) mL → dose sits on an exact mark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            case .exceedsSyringe(let units, let capacity):
                WarningCard(title: "Exceeds syringe capacity",
                            body: "\(trim(units)) units is more than the \(trim(capacity))-unit syringe holds — you'd need two draws. Consider re-constituting with more water.", tone: .warn)
            case .syringeMismatchHint(let from, let to):
                WarningCard(title: "Syringe match hint",
                            body: "With a \(from.label) syringe this draw is hard to read. A \(to.label) syringe would land closer to mid-scale.", tone: .info)
            case .unrealisticInput(let field, let value):
                WarningCard(title: "Please double-check your input",
                            body: "The value for \(field) (\(trim(value))) looks unrealistic. Calculation paused for safety.", tone: .error)
            }
        }
    }

    private func trim(_ d: Decimal) -> String {
        let s = String(format: "%.2f", NSDecimalNumber(decimal: d).doubleValue)
        return s.hasSuffix(".00") ? String(s.dropLast(3)) : s
    }
}

struct WarningCard: View {
    enum Tone { case warn, info, error }
    let title: String
    let body_: String
    let tone: Tone

    init(title: String, body: String, tone: Tone) {
        self.title = title
        self.body_ = body
        self.tone = tone
    }

    private var icon: String {
        switch tone {
        case .warn: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch tone {
        case .warn: return AppTheme.warningYellow
        case .info: return AppTheme.mint
        case .error: return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.bold())
                Text(body_)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
