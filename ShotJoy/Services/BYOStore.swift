import Foundation

enum BYOProviderID: String, Codable, CaseIterable {
    case glm, openai, deepseek, gemini, claude, custom

    var displayName: String {
        switch self {
        case .glm: return "GLM (Z.ai)"
        case .openai: return "OpenAI"
        case .deepseek: return "DeepSeek"
        case .gemini: return "Gemini"
        case .claude: return "Claude"
        case .custom: return "Custom Endpoint"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .glm: return "https://api.z.ai/api/paas/v4"
        case .openai: return "https://api.openai.com/v1"
        case .deepseek: return "https://api.deepseek.com"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .claude: return "https://api.anthropic.com/v1"
        case .custom: return ""
        }
    }

    var defaultTextModel: String {
        switch self {
        case .glm: return "glm-5.3-flash"
        case .openai: return "gpt-4o-mini"
        case .deepseek: return "deepseek-chat"
        case .gemini: return "gemini-2.5-flash"
        case .claude: return "claude-sonnet-4-5"
        case .custom: return ""
        }
    }

    var defaultVisionModel: String? {
        switch self {
        case .glm: return "glm-5.3-flash"
        case .openai: return "gpt-4o-mini"
        case .deepseek: return nil
        case .gemini: return "gemini-2.5-flash"
        case .claude: return "claude-sonnet-4-5"
        case .custom: return nil
        }
    }

    var isNativeClaude: Bool { self == .claude }
}

struct BYOProviderConfig: Codable, Identifiable {
    var id: BYOProviderID
    var baseURL: String
    var textModel: String
    var visionModel: String?
    var enabled: Bool

    var supportsVision: Bool { visionModel != nil && !visionModel!.isEmpty }
}

enum AITaskKind {
    case text
    case vision
}

enum BYOStore {
    private static let keychainService = "com.zzoutuo.ShotJoy.byo"
    private static let configKey = "byo-configs"
    private static let keyPrefix = "key-"
    private static let defaults = UserDefaults.standard

    static var configs: [BYOProviderConfig] {
        get {
            guard let data = defaults.data(forKey: configKey),
                  let list = try? JSONDecoder().decode([BYOProviderConfig].self, from: data) else {
                return []
            }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: configKey)
            }
        }
    }

    static func config(for id: BYOProviderID) -> BYOProviderConfig {
        if let existing = configs.first(where: { $0.id == id }) {
            return existing
        }
        return BYOProviderConfig(id: id, baseURL: id.defaultBaseURL, textModel: id.defaultTextModel, visionModel: id.defaultVisionModel, enabled: false)
    }

    static func setAPIKey(_ key: String, for id: BYOProviderID) {
        KeychainHelper.saveString(key, service: keychainService, account: keyPrefix + id.rawValue)
    }

    static func apiKey(for id: BYOProviderID) -> String? {
        KeychainHelper.readString(service: keychainService, account: keyPrefix + id.rawValue)
    }

    static func hasKey(for id: BYOProviderID) -> Bool {
        guard let k = apiKey(for: id) else { return false }
        return !k.isEmpty
    }

    static var hasAnyEnabledKey: Bool {
        configs.contains { $0.enabled && hasKey(for: $0.id) }
    }

    static func defaultProvider(for task: AITaskKind) -> BYOProviderID? {
        let eligible = configs.filter { cfg in
            cfg.enabled && hasKey(for: cfg.id) && (task == .text || cfg.supportsVision)
        }
        return eligible.first?.id
    }

    static func saveConfig(_ config: BYOProviderConfig) {
        var list = configs.filter { $0.id != config.id }
        list.append(config)
        configs = list
    }

    static func removeKey(for id: BYOProviderID) {
        KeychainHelper.delete(service: keychainService, account: keyPrefix + id.rawValue)
        var list = configs
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list[idx].enabled = false
        }
        configs = list
    }
}

enum BYOEngine {
    struct TestResult {
        let success: Bool
        let latencyMS: Int?
        let message: String
    }

    static func chat(messages: [[String: Any]], cfg: BYOProviderConfig, kind: AITaskKind, maxTokens: Int = 4096) async throws -> String {
        guard let key = BYOStore.apiKey(for: cfg.id), !key.isEmpty else {
            throw AIUnconfiguredError()
        }
        let model = kind == .text ? cfg.textModel : (cfg.visionModel ?? cfg.textModel)
        if cfg.id.isNativeClaude {
            return try await AnthropicAdapter.send(messages: messages, baseURL: cfg.baseURL, apiKey: key, model: model, maxTokens: maxTokens)
        }
        return try await OpenAICompatibleAdapter.send(messages: messages, baseURL: cfg.baseURL, apiKey: key, model: model, maxTokens: maxTokens, provider: cfg.id)
    }

    static func testConnection(cfg: BYOProviderConfig) async -> TestResult {
        let start = Date()
        do {
            let messages: [[String: Any]] = [
                ["role": "user", "content": "Reply with the single word: ok"]
            ]
            let answer = try await chat(messages: messages, cfg: cfg, kind: .text, maxTokens: 64)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return TestResult(success: true, latencyMS: latency, message: answer.isEmpty ? "Connected" : "Connected: \(answer.prefix(20))")
        } catch let error as GLMCloudError {
            return TestResult(success: false, latencyMS: nil, message: error.errorDescription ?? "Failed")
        } catch DecodingError.dataCorrupted {
            return TestResult(success: false, latencyMS: nil, message: "Response format not OpenAI-compatible. Check base URL.")
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                return TestResult(success: false, latencyMS: nil, message: "Could not reach base URL: \(cfg.baseURL)")
            }
            return TestResult(success: false, latencyMS: nil, message: error.localizedDescription)
        }
    }
}

enum OpenAICompatibleAdapter {
    static func send(messages: [[String: Any]], baseURL: String, apiKey: String, model: String, maxTokens: Int, provider: BYOProviderID = .custom) async throws -> String {
        var payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens
        ]
        if provider == .glm {
            payload["thinking"] = ["level": "low"]
        }
        var req = URLRequest(url: URL(string: baseURL + "/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw GLMCloudError.rejected(status: status, data: data)
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = obj?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GLMCloudError.emptyContent
        }
        return content
    }
}

enum AnthropicAdapter {
    static func send(messages: [[String: Any]], baseURL: String, apiKey: String, model: String, maxTokens: Int) async throws -> String {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens
        ]
        var system = ""
        var msgs: [[String: Any]] = []
        for m in messages {
            guard let role = m["role"] as? String else { continue }
            if role == "system" {
                if let c = m["content"] as? String { system += c }
            } else {
                var content = m["content"] ?? ""
                if let list = content as? [[String: Any]] {
                    var text = ""
                    for part in list {
                        if let t = part["text"] as? String { text += t }
                        if let img = part["image_url"] as? [String: Any], let url = img["url"] as? String, url.hasPrefix("data:") {
                            let cleaned = url.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                            let media: [String: Any] = ["type": "base64", "media_type": "image/jpeg", "data": cleaned]
                            content = ["type": "image", "source": media]
                        }
                    }
                    if !text.isEmpty {
                        content = [["type": "text", "text": text]]
                    } else if let single = content as? [String: Any] {
                        content = [single]
                    } else {
                        continue
                    }
                }
                msgs.append(["role": role, "content": content])
            }
        }
        if !system.isEmpty { body["system"] = system }
        body["messages"] = msgs

        var req = URLRequest(url: URL(string: baseURL + "/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw GLMCloudError.rejected(status: status, data: data)
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = obj?["content"] as? [[String: Any]] else {
            throw GLMCloudError.emptyContent
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw GLMCloudError.emptyContent }
        return text
    }
}
