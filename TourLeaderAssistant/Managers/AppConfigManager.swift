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
    private let fallbackFeaturePremiumCheck = false

    // MARK: - UserDefaults Keys（URL）
    private let keyUserGuideURL = "appConfig_userGuideURL"
    private let keyLinktreeURL = "appConfig_linktreeURL"

    // MARK: - UserDefaults Keys（Feature Flags）
    private let keyFeatureMemberList = "appConfig_feature_member_list"
    private let keyFeatureLocalAI = "appConfig_feature_local_ai"
    private let keyFeatureCurrencyPicker = "appConfig_feature_currency_picker"
    private let keyFeaturePremiumCheck = "appConfig_feature_premium_check"

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
    // Debug build 一律放行所有 feature flag，方便開發測試
    var isMemberListEnabled: Bool {
        #if DEBUG
        return true
        #else
        guard UserDefaults.standard.object(forKey: keyFeatureMemberList) != nil else {
            return fallbackFeatureMemberList
        }
        return UserDefaults.standard.bool(forKey: keyFeatureMemberList)
        #endif
    }

    var isLocalAIEnabled: Bool {
        #if DEBUG
        return true
        #else
        guard UserDefaults.standard.object(forKey: keyFeatureLocalAI) != nil else {
            return fallbackFeatureLocalAI
        }
        return UserDefaults.standard.bool(forKey: keyFeatureLocalAI)
        #endif
    }

    var isCurrencyPickerEnabled: Bool {
        #if DEBUG
        return true
        #else
        guard UserDefaults.standard.object(forKey: keyFeatureCurrencyPicker) != nil else {
            return fallbackFeatureCurrencyPicker
        }
        return UserDefaults.standard.bool(forKey: keyFeatureCurrencyPicker)
        #endif
    }

    // true = 開始執行進階會員 / VIP 限制；false = 全部開放
    // Debug / TestFlight 預設 false（不限制）；正式上架後從 Supabase 控制
    var isPremiumCheckEnforced: Bool {
        #if DEBUG
        return false
        #else
        guard UserDefaults.standard.object(forKey: keyFeaturePremiumCheck) != nil else {
            return fallbackFeaturePremiumCheck
        }
        return UserDefaults.standard.bool(forKey: keyFeaturePremiumCheck)
        #endif
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
                case "feature_premium_check":
                    UserDefaults.standard.set(row.value == "true", forKey: keyFeaturePremiumCheck)
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
