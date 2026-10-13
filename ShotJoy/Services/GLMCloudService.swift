import Foundation

enum GLMCloudError: LocalizedError {
    case rejected(status: Int, data: Data)
    case notConfigured
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .rejected(let status, _):
            if status == 401 { return "Cloud access was not verified. Check your subscription or restore purchases." }
            if status == 429 { return "Cloud AI is busy right now (rate limit). Please try again in a little while." }
            return "Cloud AI request failed (\(status))."
        case .notConfigured:
            return "Cloud AI is not configured yet."
        case .emptyContent:
            return "Cloud AI returned an empty response."
        }
    }
}

struct GLMResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String?
            let content: String?
        }
        let message: Message?
    }
    let choices: [Choice]?
}

enum GLMCloudService {
    static let primaryURL = URL(string: "https://cramjam-api.calcs.top")!
    static let backupURL = URL(string: "https://cramjam-proxy.iocompile67692.workers.dev")!
    static let appId = "shotjoy"

    private static let keychainService = "com.zzoutuo.ShotJoy.identity"
    private static let keychainAccount = "user-id"

    static var userId: String {
        if let existing = KeychainHelper.readString(service: keychainService, account: keychainAccount) {
            return existing
        }
        let fresh = UUID().uuidString
        KeychainHelper.saveString(fresh, service: keychainService, account: keychainAccount)
        return fresh
    }

    static var devKey: String? {
        guard let url = Bundle.main.url(forResource: "GLMProxySecret", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func generate(messages: [[String: Any]], maxTokens: Int = 4096, jsonOutput: Bool = true, appTransactionJWS: String?) async throws -> String {
        var payload: [String: Any] = [
            "model": "glm-5.3-flash",
            "messages": messages,
            "thinking": ["level": "low"],
            "max_tokens": maxTokens
        ]
        if jsonOutput {
            payload["response_format"] = ["type": "json_object"]
        }

        var body: [String: Any] = [
            "appId": appId,
            "userId": userId,
            "payload": payload
        ]
        if let devKey {
            body["devKey"] = devKey
        } else if let jws = appTransactionJWS, !jws.isEmpty {
            body["appTransaction"] = jws
        }

        var lastError: Error = GLMCloudError.notConfigured
        for url in [primaryURL, backupURL] {
            do {
                return try await post(body: body, to: url)
            } catch let error as GLMCloudError {
                if case .rejected(let status, _) = error, status != 401, status != 429 {
                    lastError = error
                    continue
                }
                throw error
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    private static func post(body: [String: Any], to url: URL) async throws -> String {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw GLMCloudError.rejected(status: status, data: data)
        }
        guard let decoded = try? JSONDecoder().decode(GLMResponse.self, from: data),
              let content = decoded.choices?.first?.message?.content, !content.isEmpty else {
            throw GLMCloudError.emptyContent
        }
        return content
    }

    static func parseVialLabel(jpegData: Data, appTransactionJWS: String?) async throws -> ParsedVial {
        guard jpegData.count < 6_000_000 else {
            throw GLMCloudError.rejected(status: 413, data: Data())
        }
        let b64 = jpegData.base64EncodedString()
        let prompt = """
        Extract from this medicine vial label photo. Reply ONLY JSON:
        {"compound":"string","total_mg":number,"formulation":"lyophilized|solution"}
        If unreadable, reply {"error":"unreadable"}.
        """
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a precise label OCR assistant. Never invent values."],
            ["role": "user", "content": [
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]],
                ["type": "text", "text": prompt]
            ]]
        ]
        let json = try await generate(messages: messages, maxTokens: 8192, appTransactionJWS: appTransactionJWS)
        return ParsedVial(fromJSON: json)
    }

    static func estimateMeal(jpegData: Data, appTransactionJWS: String?) async throws -> ParsedMeal {
        guard jpegData.count < 6_000_000 else {
            throw GLMCloudError.rejected(status: 413, data: Data())
        }
        let b64 = jpegData.base64EncodedString()
        let prompt = """
        Estimate the macros of this meal photo. Reply ONLY JSON:
        {"title":"string","calories":number,"protein_g":number,"carbs_g":number,"fat_g":number,"confidence":0.0-1.0,"candidates":[{"title":"string","calories":number,"protein_g":number,"carbs_g":number,"fat_g":number}]}
        candidates should contain the top 3 most likely interpretations, first entry is your best guess.
        """
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a careful nutrition estimator. Never invent precision you cannot see. Lower confidence when unsure."],
            ["role": "user", "content": [
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]],
                ["type": "text", "text": prompt]
            ]]
        ]
        let json = try await generate(messages: messages, maxTokens: 8192, appTransactionJWS: appTransactionJWS)
        return ParsedMeal(fromJSON: json)
    }

    static func weeklyInsight(summaryJSON: String, appTransactionJWS: String?) async throws -> [InsightCard] {
        let prompt = """
        You are a supportive GLP-1/peptide tracking assistant. Below is 7 days of AGGREGATE tracking statistics.
        Write exactly 3 insights. Each insight: a friendly headline, a 2-sentence explanation of WHY (correlations between dose timing, symptoms, protein, sites), and a confidence 0.0-1.0.
        NEVER give medical advice or dose suggestions. Never say "you should take/adjust". If a pattern is weak, say confidence below 0.5.
        Data: \(summaryJSON)
        Reply ONLY JSON: {"insights":[{"headline":"string","why":"string","confidence":0.0-1.0}]}
        """
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You write encouraging, plain-language weekly insights at 6th-grade reading level. Educational only, never medical advice."],
            ["role": "user", "content": prompt]
        ]
        let json = try await generate(messages: messages, maxTokens: 4096, appTransactionJWS: appTransactionJWS)
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(InsightEnvelope.self, from: data) else {
            throw GLMCloudError.emptyContent
        }
        return decoded.insights
    }
}

struct ParsedVial: Equatable {
    let compound: String
    let totalMG: Decimal
    let formulation: String
    let readable: Bool

    init(compound: String, totalMG: Decimal, formulation: String, readable: Bool) {
        self.compound = compound
        self.totalMG = totalMG
        self.formulation = formulation
        self.readable = readable
    }

    init(fromJSON json: String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["error"] == nil else {
            self.init(compound: "", totalMG: 0, formulation: "", readable: false)
            return
        }
        let compound = obj["compound"] as? String ?? ""
        let mg: Decimal
        if let n = obj["total_mg"] as? NSNumber {
            mg = Decimal(string: n.stringValue) ?? 0
        } else {
            mg = 0
        }
        let formulation = obj["formulation"] as? String ?? "lyophilized"
        self.init(compound: compound, totalMG: mg, formulation: formulation, readable: !compound.isEmpty && mg > 0)
    }
}

struct ParsedMeal {
    struct Candidate {
        let title: String
        let calories: Int
        let proteinG: Decimal
        let carbsG: Decimal
        let fatG: Decimal
    }
    let title: String
    let calories: Int
    let proteinG: Decimal
    let carbsG: Decimal
    let fatG: Decimal
    let confidence: Double
    let candidates: [Candidate]

    init(fromJSON json: String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            title = ""; calories = 0; proteinG = 0; carbsG = 0; fatG = 0; confidence = 0; candidates = []
            return
        }
        title = obj["title"] as? String ?? ""
        calories = obj["calories"] as? Int ?? 0
        proteinG = Decimal(string: "\(obj["protein_g"] as? Double ?? 0)") ?? 0
        carbsG = Decimal(string: "\(obj["carbs_g"] as? Double ?? 0)") ?? 0
        fatG = Decimal(string: "\(obj["fat_g"] as? Double ?? 0)") ?? 0
        confidence = obj["confidence"] as? Double ?? 0
        var cands: [Candidate] = []
        if let list = obj["candidates"] as? [[String: Any]] {
            for c in list {
                cands.append(Candidate(
                    title: c["title"] as? String ?? "",
                    calories: c["calories"] as? Int ?? 0,
                    proteinG: Decimal(string: "\(c["protein_g"] as? Double ?? 0)") ?? 0,
                    carbsG: Decimal(string: "\(c["carbs_g"] as? Double ?? 0)") ?? 0,
                    fatG: Decimal(string: "\(c["fat_g"] as? Double ?? 0)") ?? 0
                ))
            }
        }
        candidates = cands
    }
}

struct InsightEnvelope: Codable {
    let insights: [InsightCard]
}

struct InsightCard: Codable, Identifiable {
    var id: UUID { UUID() }
    let headline: String
    let why: String
    let confidence: Double
}
