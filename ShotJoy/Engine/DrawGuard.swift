import Foundation

enum SyringeType: String, Codable, CaseIterable {
    case u100, u50, u40, u30

    var unitsPerML: Decimal {
        switch self {
        case .u100: return 100
        case .u50: return 50
        case .u40: return 40
        case .u30: return 30
        }
    }

    var label: String {
        switch self {
        case .u100: return "U-100"
        case .u50: return "U-50"
        case .u40: return "U-40"
        case .u30: return "U-30"
        }
    }
}

struct DoseResult: Equatable {
    let concentrationMCGPerML: Decimal
    let volumeML: Decimal
    let units: Decimal
    let dosesRemaining: Int
    let warnings: [DoseWarning]
}

enum DoseWarning: Equatable {
    case drawTooSmall(units: Decimal, suggestedWaterML: [Decimal])
    case exceedsSyringe(units: Decimal, capacity: Decimal)
    case syringeMismatchHint(from: SyringeType, to: SyringeType)
    case unrealisticInput(field: String, value: Decimal)
}

struct Reconstitution {
    let vialMassMG: Decimal
    let bacWaterML: Decimal
    let syringeType: SyringeType
}

enum DrawGuard {

    static func suggestedWaterML(vialMG: Decimal, doseMCG: Decimal, targets: [Decimal] = [10, 15, 20, 25, 30]) -> [Decimal] {
        guard doseMCG > 0, vialMG > 0 else { return [] }
        return targets.map { ($0 * vialMG * 10 / doseMCG) }
            .filter { $0 > 0 && $0 <= 5 }
    }

    static func calculate(_ r: Reconstitution, doseMCG: Decimal) -> DoseResult {
        var warnings: [DoseWarning] = []

        if r.vialMassMG <= 0 || r.vialMassMG > 100 {
            warnings.append(.unrealisticInput(field: "vialMassMG", value: r.vialMassMG))
        }
        if r.bacWaterML <= 0 || r.bacWaterML > 10 {
            warnings.append(.unrealisticInput(field: "bacWaterML", value: r.bacWaterML))
        }
        if doseMCG <= 0 || doseMCG > r.vialMassMG * 1000 {
            warnings.append(.unrealisticInput(field: "doseMCG", value: doseMCG))
        }

        var concentration: Decimal = 0
        if r.bacWaterML > 0 {
            concentration = (r.vialMassMG * 1000) / r.bacWaterML
        }

        var volumeML: Decimal = 0
        var units: Decimal = 0
        if concentration > 0 {
            volumeML = doseMCG / concentration
            units = volumeML * r.syringeType.unitsPerML
        }

        if units > 0 && units < 5 {
            warnings.append(.drawTooSmall(units: units, suggestedWaterML: suggestedWaterML(vialMG: r.vialMassMG, doseMCG: doseMCG)))
        }

        if units > r.syringeType.unitsPerML {
            warnings.append(.exceedsSyringe(units: units, capacity: r.syringeType.unitsPerML))
        }

        if units > 5, units <= r.syringeType.unitsPerML {
            for type in SyringeType.allCases where type != r.syringeType {
                let altUnits = volumeML * type.unitsPerML
                if altUnits >= 5 && altUnits <= type.unitsPerML && units < 5 * (r.syringeType.unitsPerML / type.unitsPerML) {
                    warnings.append(.syringeMismatchHint(from: r.syringeType, to: type))
                    break
                }
            }
        }

        let remaining = dosesRemaining(remainingMG: r.vialMassMG, typicalDoseMCG: doseMCG)
        return DoseResult(concentrationMCGPerML: concentration, volumeML: volumeML, units: units, dosesRemaining: remaining, warnings: warnings)
    }

    static func dosesRemaining(remainingMG: Decimal, typicalDoseMCG: Decimal?, vial: Vial? = nil) -> Int {
        let remainingMCG = remainingMG * 1000
        guard remainingMCG > 0 else { return 0 }
        var dose: Decimal = 0
        if let t = typicalDoseMCG, t > 0 {
            dose = t
        } else {
            dose = remainingMCG / 10
        }
        guard dose > 0 else { return 0 }
        let raw = remainingMCG / dose
        return max(Int(truncating: raw as NSDecimalNumber), 0)
    }

    static func calculateBlend(components: [(name: String, massMG: Decimal)], bacWaterML: Decimal, doseMCGTotal: Decimal, syringe: SyringeType) -> (results: [(name: String, units: Decimal, share: Double)], totalUnits: Decimal, warnings: [DoseWarning]) {
        var warnings: [DoseWarning] = []
        let totalMG = components.reduce(Decimal(0)) { $0 + $1.massMG }
        if totalMG <= 0 || bacWaterML <= 0 {
            warnings.append(.unrealisticInput(field: "blend", value: totalMG))
            return ([], 0, warnings)
        }
        let concentration = (totalMG * 1000) / bacWaterML
        let volumeML = doseMCGTotal / concentration
        let totalUnits = volumeML * syringe.unitsPerML
        var results: [(String, Decimal, Double)] = []
        for c in components {
            let share = Double(truncating: (c.massMG / totalMG) as NSDecimalNumber)
            let itemUnits = totalUnits * Decimal(share)
            results.append((c.name, itemUnits, share))
        }
        let checkSum = results.reduce(Decimal(0)) { $0 + $1.1 }
        if checkSum != totalUnits {
            warnings.append(.unrealisticInput(field: "blendConservation", value: checkSum))
        }
        if totalUnits < 5 {
            warnings.append(.drawTooSmall(units: totalUnits, suggestedWaterML: []))
        }
        return (results, totalUnits, warnings)
    }
}
