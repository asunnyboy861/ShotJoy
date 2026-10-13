import Foundation
import PDFKit
import SwiftUI

enum PDFReportService {

    static func generateReport(doseLogs: [DoseLog], symptomLogs: [SymptomLog], weightEntries: [WeightEntry], vials: [Vial], goalSettings: GoalSettings?, startDate: Date, endDate: Date) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let disclaimer = "Educational only — not medical advice. Always follow your prescriber's instructions."
        let titleFont = UIFont.boldSystemFont(ofSize: 22)
        let headFont = UIFont.boldSystemFont(ofSize: 14)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        let smallFont = UIFont.systemFont(ofSize: 8)

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        let filteredDoses = doseLogs.filter { $0.loggedAt >= startDate && $0.loggedAt <= endDate }.sorted { $0.loggedAt > $1.loggedAt }
        let filteredSymptoms = symptomLogs.filter { $0.loggedAt >= startDate && $0.loggedAt <= endDate }.sorted { $0.loggedAt > $1.loggedAt }
        let filteredWeights = weightEntries.filter { $0.date >= startDate && $0.date <= endDate }.sorted { $0.date < $1.date }

        var y: CGFloat = 40

        return renderer.pdfData { ctx in
            ctx.beginPage()
            "ShotJoy — Doctor-Ready Report".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: titleFont]); y += 26
            "Range: \(fmt.string(from: startDate)) – \(fmt.string(from: endDate))".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: bodyFont]); y += 30

            "Shots Logged (\(filteredDoses.count))".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: headFont]); y += 18
            for log in filteredDoses.prefix(60) {
                let line = "\(fmt.string(from: log.loggedAt)) · \(log.compoundName) · \(NSDecimalNumber(decimal: log.doseMCG).stringValue) mcg · \(log.syringe) · \(BodySites.label(for: log.site))"
                line.draw(at: CGPoint(x: 48, y: y), withAttributes: [.font: bodyFont]); y += 14
                if y > 720 { ctx.beginPage(); y = 40 }
            }

            y += 12
            "Symptoms (\(filteredSymptoms.count))".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: headFont]); y += 18
            for s in filteredSymptoms.prefix(60) {
                let line = "\(fmt.string(from: s.loggedAt)) · \(s.name) · severity \(s.severity)/5"
                line.draw(at: CGPoint(x: 48, y: y), withAttributes: [.font: bodyFont]); y += 14
                if y > 720 { ctx.beginPage(); y = 40 }
            }

            y += 12
            "Weight (\(filteredWeights.count) entries)".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: headFont]); y += 18
            for w in filteredWeights.prefix(60) {
                let kg = NSDecimalNumber(decimal: w.kg).doubleValue
                let lb = kg * 2.20462
                let line = "\(fmt.string(from: w.date)) · \(String(format: "%.1f", kg)) kg (\(String(format: "%.1f", lb)) lb)"
                line.draw(at: CGPoint(x: 48, y: y), withAttributes: [.font: bodyFont]); y += 14
                if y > 720 { ctx.beginPage(); y = 40 }
            }

            y += 12
            "Active Vials (\(vials.count))".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: headFont]); y += 18
            for v in vials.prefix(30) {
                let line = "\(v.compoundName) · \(NSDecimalNumber(decimal: v.massMG).stringValue) mg total · \(NSDecimalNumber(decimal: v.remainingMG).stringValue) mg remaining · \(v.syringeType.uppercased())"
                line.draw(at: CGPoint(x: 48, y: y), withAttributes: [.font: bodyFont]); y += 14
                if y > 720 { ctx.beginPage(); y = 40 }
            }

            if y > 700 { ctx.beginPage(); y = 40 } else { y += 20 }
            disclaimer.draw(
                in: CGRect(x: 40, y: y, width: pageRect.width - 80, height: 30),
                withAttributes: [.font: smallFont, .foregroundColor: UIColor.darkGray]
            )
        }
    }
}
