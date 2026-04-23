import Foundation
import Supabase

@MainActor
@Observable
class AppConfigManager {
    static let shared = AppConfigManager()

    // MARK: - Fallback 預設值
    private let fallbackUserGuideURL = "https://rooms-cross-i4v.craft.me/bp4w0xe2ndW4sH"
    private let fallbackLinktreeURL = "https://linktr.ee/clear.karma.tour"

    // MARK: - UserDefaults Keys
    private let keyUserGuideURL = "appConfig_userGuideURL"
    private let keyLinktreeURL = "appConfig_linktreeURL"

    // MARK: - 對外屬性
    var userGuideURL: URL {
        let string = UserDefaults.standard.string(forKey: keyUserGuideURL) ?? fallbackUserGuideURL
        return URL(string: string) ?? URL(string: fallbackUserGuideURL)!
    }

    var linktreeURL: URL {
        let string = UserDefaults.standard.string(forKey: keyLinktreeURL) ?? fallbackLinktreeURL
        return URL(string: string) ?? URL(string: fallbackLinktreeURL)!
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
