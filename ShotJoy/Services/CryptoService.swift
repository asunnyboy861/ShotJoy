import Foundation
import CryptoKit
import Security

enum CryptoService {
    private static let keychainService = "com.zzoutuo.ShotJoy.crypto"
    private static let keychainAccount = "field-encryption-key"

    private static func loadKey() -> SymmetricKey {
        if let data = KeychainHelper.read(service: keychainService, account: keychainAccount) {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        KeychainHelper.save(data, service: keychainService, account: keychainAccount)
        return key
    }

    static func encrypt(_ data: Data) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: loadKey())
        guard let combined = sealed.combined else {
            throw NSError(domain: "CryptoService", code: 1)
        }
        return combined
    }

    static func decrypt(_ data: Data) -> Data? {
        guard let box = try? AES.GCM.SealedBox(combined: data) else { return nil }
        return try? AES.GCM.open(box, using: loadKey())
    }

    static func encryptString(_ value: String) -> Data? {
        try? encrypt(Data(value.utf8))
    }

    static func decryptString(_ data: Data?) -> String? {
        guard let data else { return nil }
        guard let plain = decrypt(data) else { return nil }
        return String(data: plain, encoding: .utf8)
    }
}

enum KeychainHelper {
    static func save(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func saveString(_ value: String, service: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        save(data, service: service, account: account)
    }

    static func readString(service: String, account: String) -> String? {
        guard let data = read(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
