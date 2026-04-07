import Foundation
import Security

struct KeychainManager {
    private static let service = "com.tourleaderassistant.app"
    private static let account = "device_uuid"

    /// 取得裝置唯一 UUID，沒有就自動建立並存入 Keychain
    static var deviceUUID: String {
        if let existing = load() {
            return existing
        }
        let newUUID = UUID().uuidString
        save(newUUID)
        return newUUID
    }

    // MARK: - Private

    private static func save(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData:   data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }

        return string
    }
}
