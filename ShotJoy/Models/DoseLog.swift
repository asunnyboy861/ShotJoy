import SwiftData
import Foundation

@Model
final class DoseLog {
    var id: UUID = UUID()
    var compoundName: String = ""
    var doseMCG: Decimal = 0
    var units: Decimal = 0
    var syringe: String = "u100"
    var site: String = ""
    var loggedAt: Date = Date()
    var notes: String = ""
    var isBackfill: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \SymptomLog.doseRef) var symptoms: [SymptomLog]? = nil

    init(compoundName: String, doseMCG: Decimal, units: Decimal, syringe: String, site: String, loggedAt: Date = Date(), notes: String = "", isBackfill: Bool = false) {
        self.compoundName = compoundName
        self.doseMCG = doseMCG
        self.units = units
        self.syringe = syringe
        self.site = site
        self.loggedAt = loggedAt
        self.notes = notes
        self.isBackfill = isBackfill
    }
}

@Model
final class SymptomLog {
    var id: UUID = UUID()
    var name: String = ""
    var severity: Int = 1
    var loggedAt: Date = Date()
    var doseRef: DoseLog? = nil

    init(name: String, severity: Int, loggedAt: Date = Date()) {
        self.name = name
        self.severity = severity
        self.loggedAt = loggedAt
    }
}

@Model
final class MealLog {
    var id: UUID = UUID()
    var loggedAt: Date = Date()
    var title: String = ""
    var calories: Int = 0
    var proteinG: Decimal = 0
    var carbsG: Decimal = 0
    var fatG: Decimal = 0
    var confidence: Double = 0
    var source: String = "manual"
    var itemsJSON: String = "[]"

    init(loggedAt: Date = Date(), title: String, calories: Int, proteinG: Decimal, carbsG: Decimal, fatG: Decimal, confidence: Double, source: String, itemsJSON: String = "[]") {
        self.loggedAt = loggedAt
        self.title = title
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.confidence = confidence
        self.source = source
        self.itemsJSON = itemsJSON
    }
}

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var kg: Decimal = 0
    var source: String = "manual"

    init(date: Date = Date(), kg: Decimal, source: String = "manual") {
        self.date = date
        self.kg = kg
        self.source = source
    }
}

@Model
final class GoalSettings {
    var id: UUID = UUID()
    var proteinTargetG: Decimal = 100
    var waterTargetML: Int = 2500
    var weightGoalKg: Decimal = 0
    var reminderEnabled: Bool = false
    var reminderWeekday: Int = 6
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var typicalDoseMCG: Decimal = 0
    var cadenceDays: Int = 7
    var firstShotDate: Date? = nil
    var cloudSyncEnabled: Bool = false

    init() {}
}

enum SymptomPresets {
    static let all: [String] = [
        "Nausea", "Fatigue", "Headache", "Vomiting", "Diarrhea", "Constipation", "Abdominal pain",
        "Bloating", "Heartburn", "Loss of appetite", "Dizziness", "Injection site pain", "Injection site redness",
        "Injection site itching", "Bruising", "Low blood sugar", "Increased heart rate", "Burping", "Gas",
        "Dry mouth", "Thirst", "Muscle aches", "Joint pain", "Back pain", "Insomnia", "Drowsiness",
        "Anxiety", "Mood swings", "Brain fog", "Hair shedding", "Acne", "Rash", "Itchy skin",
        "Chills", "Fever", "Sweating", "Tremor", "Vision changes", "Swelling", "Water retention",
        "Cramping", "Weakness", "Dehydration", "Sulfur burps"
    ]
}

enum BodySites {
    static let all: [(id: String, label: String, zone: String)] = [
        ("abdomen-UL", "Abdomen Upper Left", "abdomen"),
        ("abdomen-UR", "Abdomen Upper Right", "abdomen"),
        ("abdomen-LL", "Abdomen Lower Left", "abdomen"),
        ("abdomen-LR", "Abdomen Lower Right", "abdomen"),
        ("thigh-L-outer", "Left Thigh Outer", "thigh"),
        ("thigh-R-outer", "Right Thigh Outer", "thigh"),
        ("arm-L-back", "Left Arm Back", "arm"),
        ("arm-R-back", "Right Arm Back", "arm")
    ]

    static func label(for id: String) -> String {
        all.first { $0.id == id }?.label ?? id
    }

    static func recommendedNext(recent: [DoseLog]) -> String {
        let cutoff = Date.now.addingTimeInterval(-28 * 86400)
        let recentSites = recent.filter { $0.loggedAt >= cutoff }.compactMap { log -> (String, Date)? in
            guard !log.site.isEmpty else { return nil }
            return (log.site, log.loggedAt)
        }
        let counts = Dictionary(grouping: recentSites, by: { $0.0 }).mapValues { $0.count }
        let minCount = counts.values.min() ?? 0
        let leastUsed = all.filter { (counts[$0.id] ?? 0) == minCount }
        if leastUsed.isEmpty { return all[0].id }
        return leastUsed.randomElement()!.id
    }
}
