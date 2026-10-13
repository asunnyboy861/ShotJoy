import Foundation

enum PlasmaCurve {
    static func percent(fullDoseMCG: Decimal, halfLifeHours: Double, hoursSinceDose: Double) -> Double {
        guard halfLifeHours > 0 else { return 0 }
        return 100.0 * pow(0.5, hoursSinceDose / halfLifeHours)
    }

    static func currentLevel(doseLogs: [DoseLog], halfLifeHours: Double, now: Date = Date()) -> Double? {
        guard let last = doseLogs.max(by: { $0.loggedAt < $1.loggedAt }) else { return nil }
        let hours = now.timeIntervalSince(last.loggedAt) / 3600
        guard hours >= 0 else { return nil }
        return percent(fullDoseMCG: 100, halfLifeHours: halfLifeHours, hoursSinceDose: hours)
    }

    static func curvePoints(halfLifeHours: Double, cadenceDays: Int, samples: Int = 60) -> [(x: Double, y: Double)] {
        let total = Double(cadenceDays) * 24
        return (0..<samples).map { i in
            let x = total * Double(i) / Double(samples - 1)
            return (x, percent(fullDoseMCG: 100, halfLifeHours: halfLifeHours, hoursSinceDose: x))
        }
    }

    static func phaseLabel(percent: Double) -> String {
        switch percent {
        case 80...: return "Just dosed"
        case 45..<80: return "Steady phase"
        case 20..<45: return "Waning"
        default: return "Trough"
        }
    }
}
