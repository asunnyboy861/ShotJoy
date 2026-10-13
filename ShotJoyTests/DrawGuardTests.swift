import XCTest
@testable import ShotJoy

final class DrawGuardTests: XCTestCase {

    func testBasicConcentration() {
        let r = DrawGuard.calculate(Reconstitution(vialMassMG: 5, bacWaterML: 2, syringeType: .u100), doseMCG: 250)
        XCTAssertEqual(r.concentrationMCGPerML, 2500)
        XCTAssertEqual(r.volumeML, Decimal(string: "0.1")!)
        XCTAssertEqual(r.units, 10)
    }

    func testUnitsConversionU40() {
        let r = DrawGuard.calculate(Reconstitution(vialMassMG: 5, bacWaterML: 2, syringeType: .u40), doseMCG: 250)
        XCTAssertEqual(r.volumeML, Decimal(string: "0.1")!)
        XCTAssertEqual(r.units, 4)
        XCTAssertTrue(r.warnings.contains { w in
            if case .drawTooSmall = w { return true }
            return false
        })
    }

    func testDrawTooSmallSuggestsWater() {
        let r = DrawGuard.calculate(Reconstitution(vialMassMG: 1, bacWaterML: 2, syringeType: .u100), doseMCG: 20)
        let warnings = r.warnings
        guard case .drawTooSmall(_, let suggestions)? = warnings.first(where: { w in if case .drawTooSmall = w { return true }; return false }) else {
            return XCTFail("expected drawTooSmall")
        }
        XCTAssertFalse(suggestions.isEmpty)
        for s in suggestions {
            let c = (1 * 1000) / s
            let units = (20 / c) * 100
            XCTAssertEqual(units, Decimal(Int(truncating: units as NSDecimalNumber)), "suggested water should land on exact integer mark")
        }
    }

    func testMgToMcgThousandFoldCheck() {
        let r = DrawGuard.calculate(Reconstitution(vialMassMG: 0, bacWaterML: 2, syringeType: .u100), doseMCG: 250)
        XCTAssertTrue(r.warnings.contains { w in
            if case .unrealisticInput(let field, _) = w { return field == "vialMassMG" }
            return false
        })
        let r2 = DrawGuard.calculate(Reconstitution(vialMassMG: 1, bacWaterML: 2, syringeType: .u100), doseMCG: 5000)
        XCTAssertTrue(r2.warnings.contains { w in
            if case .unrealisticInput(let field, _) = w { return field == "doseMCG" }
            return false
        })
    }

    func testExceedsSyringe() {
        let r = DrawGuard.calculate(Reconstitution(vialMassMG: 5, bacWaterML: 2, syringeType: .u30), doseMCG: 4000)
        XCTAssertTrue(r.warnings.contains { w in
            if case .exceedsSyringe = w { return true }
            return false
        })
    }

    func testDivisionByZeroGuard() {
        let r = DrawGuard.calculate(Reconstitution(vialMassMG: 5, bacWaterML: 0, syringeType: .u100), doseMCG: 250)
        XCTAssertTrue(r.warnings.contains { w in
            if case .unrealisticInput = w { return true }
            return false
        })
        XCTAssertEqual(r.concentrationMCGPerML, 0)
    }

    func testBlendConservation() {
        let blend = DrawGuard.calculateBlend(
            components: [("A", 5), ("B", 5)],
            bacWaterML: 2,
            doseMCGTotal: 500,
            syringe: .u100
        )
        XCTAssertEqual(blend.totalUnits, 10)
        let sum = blend.results.reduce(Decimal(0)) { $0 + $1.units }
        XCTAssertEqual(sum, blend.totalUnits, "itemized units must conserve the total")
        XCTAssertEqual(blend.results[0].share, 0.5, accuracy: 0.001)
    }

    func testPlasmaCurve() {
        XCTAssertEqual(PlasmaCurve.percent(fullDoseMCG: 100, halfLifeHours: 168, hoursSinceDose: 0), 100, accuracy: 0.001)
        XCTAssertEqual(PlasmaCurve.percent(fullDoseMCG: 100, halfLifeHours: 168, hoursSinceDose: 168), 50, accuracy: 0.001)
        XCTAssertEqual(PlasmaCurve.percent(fullDoseMCG: 100, halfLifeHours: 168, hoursSinceDose: 336), 25, accuracy: 0.001)
    }

    func testDecimalNoFloatDrift() {
        let r = DrawGuard.calculate(Reconstitution(vialMassMG: 3, bacWaterML: 3, syringeType: .u100), doseMCG: 100)
        XCTAssertEqual(r.concentrationMCGPerML, 1000)
        XCTAssertEqual(r.volumeML, Decimal(string: "0.1")!)
        XCTAssertEqual(r.units, 10)
    }

    func testDosesRemaining() {
        XCTAssertEqual(DrawGuard.dosesRemaining(remainingMG: 5, typicalDoseMCG: 250), 20)
        XCTAssertEqual(DrawGuard.dosesRemaining(remainingMG: 0, typicalDoseMCG: 250), 0)
    }
}
