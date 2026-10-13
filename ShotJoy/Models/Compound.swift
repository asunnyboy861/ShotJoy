import SwiftData
import Foundation

@Model
final class Compound {
    var id: UUID = UUID()
    var name: String = ""
    var kind: String = "peptide"
    var halfLifeHours: Double = 24
    var isPreset: Bool = false
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \Vial.compound) var vials: [Vial]? = nil

    init(name: String, kind: String, halfLifeHours: Double, isPreset: Bool) {
        self.name = name
        self.kind = kind
        self.halfLifeHours = halfLifeHours
        self.isPreset = isPreset
    }
}

@Model
final class Vial {
    var id: UUID = UUID()
    var compound: Compound? = nil
    var compoundName: String = ""
    var massMG: Decimal = 1
    var bacWaterML: Decimal = 2
    var remainingMG: Decimal = 1
    var syringeType: String = "u100"
    var reconstitutedAt: Date? = nil
    var photoData: Data? = nil
    var createdAt: Date = Date()

    init(compoundName: String, massMG: Decimal, bacWaterML: Decimal, remainingMG: Decimal, syringeType: String, reconstitutedAt: Date? = nil) {
        self.compoundName = compoundName
        self.massMG = massMG
        self.bacWaterML = bacWaterML
        self.remainingMG = remainingMG
        self.syringeType = syringeType
        self.reconstitutedAt = reconstitutedAt
    }

    var concentrationMCGPerML: Decimal {
        guard bacWaterML > 0 else { return 0 }
        return massMG * 1000 / bacWaterML
    }

    var dosesRemaining: Int {
        DrawGuard.dosesRemaining(remainingMG: remainingMG, typicalDoseMCG: nil, vial: self)
    }
}
