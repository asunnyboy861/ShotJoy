import Foundation
import FoundationModels

@MainActor
final class AppleOnDeviceAI: ObservableObject {
    static let shared = AppleOnDeviceAI()
    static let freeDailyLimit = 5

    @Published var tasksUsedToday: Int = UserDefaults.standard.integer(forKey: "onDeviceTasksUsedToday")
    @Published var tasksUsedDate: String = UserDefaults.standard.string(forKey: "onDeviceTasksDate") ?? ""

    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var isPro: Bool {
        PurchaseManager.shared.isPro
    }

    var quotaRemaining: Int {
        if isPro { return Int.max }
        resetIfNewDay()
        return max(Self.freeDailyLimit - tasksUsedToday, 0)
    }

    var canGenerate: Bool {
        isPro || hasAPIKey || (isAvailable && quotaRemaining > 0)
    }

    var hasAPIKey: Bool {
        BYOStore.hasAnyEnabledKey
    }

    private func resetIfNewDay() {
        let key = Self.dayKey()
        if tasksUsedDate != key {
            tasksUsedDate = key
            tasksUsedToday = 0
            UserDefaults.standard.set(key, forKey: "onDeviceTasksDate")
            UserDefaults.standard.set(0, forKey: "onDeviceTasksUsedToday")
        }
    }

    static func dayKey() -> String {
        DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
    }

    private func consume() {
        resetIfNewDay()
        tasksUsedToday += 1
        UserDefaults.standard.set(tasksUsedToday, forKey: "onDeviceTasksUsedToday")
    }

    func summarizeWeek(entries: [DayEntry]) async throws -> String {
        guard canGenerate else {
            throw AIUnconfiguredError()
        }
        consume()
        let session = LanguageModelSession()
        let data = entries.map { "\($0.date): nausea=\($0.nauseaScore), protein=\($0.proteinG)g, logged=\($0.shotLogged)" }.joined(separator: "\n")
        let prompt = """
        Summarize this GLP-1 tracking week in 3 friendly sentences, 6th-grade reading level.
        Data:
        \(data)
        Never give medical advice. Encourage contacting their clinician for concerns.
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

struct DayEntry {
    let date: String
    let nauseaScore: Int
    let proteinG: Int
    let shotLogged: Bool
}

struct AIUnconfiguredError: LocalizedError {
    var errorDescription: String? {
        "AI is taking a break. Go Pro for unlimited insights, or add your own API key in Settings."
    }
}
