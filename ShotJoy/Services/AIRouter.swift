import Foundation

enum AIRoute {
    case onDeviceApple
    case sharedWorker
    case byoProvider
    case blocked
}

enum AIRouter {

    static func route(for task: AITaskKind, pro: Bool, cloudQuota: Bool, byoProvider: BYOProviderID?, onDeviceAvailable: Bool, onDeviceQuotaRemaining: Int) -> AIRoute {
        if task == .vision {
            if let byoProvider, BYOStore.config(for: byoProvider).supportsVision {
                return .byoProvider
            }
            if cloudQuota || pro {
                return .sharedWorker
            }
            if onDeviceAvailable && onDeviceQuotaRemaining > 0 {
                return .onDeviceApple
            }
            return .blocked
        }
        if byoProvider != nil {
            return .byoProvider
        }
        if cloudQuota {
            return .sharedWorker
        }
        if onDeviceAvailable && onDeviceQuotaRemaining > 0 {
            return .onDeviceApple
        }
        return .blocked
    }

    static func aggregateSummary(doseLogs: [DoseLog], symptomLogs: [SymptomLog], mealLogs: [MealLog], weightEntries: [WeightEntry], vials: [Vial]) -> String {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        var days: [String: (nausea: Int, nauseaCount: Int, protein: Decimal, proteinCount: Int, shots: Int, sites: [String])] = [:]
        for log in symptomLogs where log.loggedAt >= weekAgo {
            let key = DateFormatter.localizedString(from: log.loggedAt, dateStyle: .short, timeStyle: .none)
            var d = days[key] ?? (0, 0, 0, 0, 0, [])
            if log.name == "Nausea" {
                d.nausea += log.severity
                d.nauseaCount += 1
            }
            days[key] = d
        }
        for log in mealLogs where log.loggedAt >= weekAgo {
            let key = DateFormatter.localizedString(from: log.loggedAt, dateStyle: .short, timeStyle: .none)
            var d = days[key] ?? (0, 0, 0, 0, 0, [])
            d.protein += log.proteinG
            d.proteinCount += 1
            days[key] = d
        }
        for log in doseLogs where log.loggedAt >= weekAgo {
            let key = DateFormatter.localizedString(from: log.loggedAt, dateStyle: .short, timeStyle: .none)
            var d = days[key] ?? (0, 0, 0, 0, 0, [])
            d.shots += 1
            if !log.site.isEmpty { d.sites.append(log.site) }
            days[key] = d
        }

        var dayEntries: [[String: Any]] = []
        for (key, d) in days {
            var entry: [String: Any] = [
                "date": key,
                "shots": d.shots,
                "nausea_sum": d.nausea,
                "nausea_count": d.nauseaCount,
                "protein_total_g": NSDecimalNumber(decimal: d.protein).doubleValue
            ]
            if let site = d.sites.first { entry["site"] = site }
            dayEntries.append(entry)
        }
        let weightKgs = weightEntries.filter { $0.date >= weekAgo }.map { NSDecimalNumber(decimal: $0.kg).doubleValue }
        let payload: [String: Any] = [
            "days": dayEntries,
            "weights_kg": weightKgs,
            "active_vials": vials.count,
            "aggregation_note": "aggregate statistics only, no identity data"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func weekEntries(doseLogs: [DoseLog], symptomLogs: [SymptomLog], mealLogs: [MealLog]) -> [DayEntry] {
        let calendar = Calendar.current
        var result: [DayEntry] = []
        for offset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let key = DateFormatter.localizedString(from: day, dateStyle: .short, timeStyle: .none)
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let nausea = symptomLogs.filter { $0.loggedAt >= dayStart && $0.loggedAt < dayEnd && $0.name == "Nausea" }.map { $0.severity }.max() ?? 0
            let protein = mealLogs.filter { $0.loggedAt >= dayStart && $0.loggedAt < dayEnd }.reduce(Decimal(0)) { $0 + $1.proteinG }
            let shot = doseLogs.contains { $0.loggedAt >= dayStart && $0.loggedAt < dayEnd }
            result.append(DayEntry(date: key, nauseaScore: nausea, proteinG: Int(truncating: protein as NSDecimalNumber), shotLogged: shot))
        }
        return result
    }
}
