import Foundation
import Supabase

@MainActor
@Observable
class AppConfigManager {
    static let shared = AppConfigManager()

    // MARK: - Fallback 預設值（URL）
    private let fallbackUserGuideURL = "https://rooms-cross-i4v.craft.me/bp4w0xe2ndW4sH"
    private let fallbackLinktreeURL = "https://linktr.ee/clear.karma.tour"

    // MARK: - Fallback 預設值（Feature Flags）
    private let fallbackFeatureMemberList = false
    private let fallbackFeatureLocalAI = false
    private let fallbackFeatureCurrencyPicker = false

    // MARK: - UserDefaults Keys（URL）
    private let keyUserGuideURL = "appConfig_userGuideURL"
    private let keyLinktreeURL = "appConfig_linktreeURL"

    // MARK: - UserDefaults Keys（Feature Flags）
    private let keyFeatureMemberList = "appConfig_feature_member_list"
    private let keyFeatureLocalAI = "appConfig_feature_local_ai"
    private let keyFeatureCurrencyPicker = "appConfig_feature_currency_picker"

    // MARK: - 對外屬性（URL）
    var userGuideURL: URL {
        let string = UserDefaults.standard.string(forKey: keyUserGuideURL) ?? fallbackUserGuideURL
        return URL(string: string) ?? URL(string: fallbackUserGuideURL)!
    }

    var linktreeURL: URL {
        let string = UserDefaults.standard.string(forKey: keyLinktreeURL) ?? fallbackLinktreeURL
        return URL(string: string) ?? URL(string: fallbackLinktreeURL)!
    }

    // MARK: - 對外屬性（Feature Flags）
    var isMemberListEnabled: Bool {
        guard UserDefaults.standard.object(forKey: keyFeatureMemberList) != nil else {
            return fallbackFeatureMemberList
        }
        return UserDefaults.standard.bool(forKey: keyFeatureMemberList)
    }

    var isLocalAIEnabled: Bool {
        guard UserDefaults.standard.object(forKey: keyFeatureLocalAI) != nil else {
            return fallbackFeatureLocalAI
        }
        return UserDefaults.standard.bool(forKey: keyFeatureLocalAI)
    }

    var isCurrencyPickerEnabled: Bool {
        guard UserDefaults.standard.object(forKey: keyFeatureCurrencyPicker) != nil else {
            return fallbackFeatureCurrencyPicker
        }
        return UserDefaults.standard.bool(forKey: keyFeatureCurrencyPicker)
    }

    private init() {}

    // MARK: - 從 Supabase 抓取設定（App 啟動時靜默呼叫）
    func fetchConfig() async {
        do {
            let rows: [AppConfigRow] = try await SupabaseManager.shared.client
                .from("app_config")
                .select("key, value")
                .execute()
                .value

            for row in rows {
                switch row.key {
                case "user_guide_url":
                    UserDefaults.standard.set(row.value, forKey: keyUserGuideURL)
                case "linktree_url":
                    UserDefaults.standard.set(row.value, forKey: keyLinktreeURL)
                case "feature_member_list":
                    UserDefaults.standard.set(row.value == "true", forKey: keyFeatureMemberList)
                case "feature_local_ai":
                    UserDefaults.standard.set(row.value == "true", forKey: keyFeatureLocalAI)
                case "feature_currency_picker":
                    UserDefaults.standard.set(row.value == "true", forKey: keyFeatureCurrencyPicker)
                default:
                    break
                }
            }
            print("AppConfig 同步完成，共 \(rows.count) 筆")
        } catch {
            print("AppConfig 同步失敗，使用快取或預設值：\(error)")
        }
    }
}

// MARK: - Codable

private struct AppConfigRow: Codable {
    let key: String
    let value: String
}
