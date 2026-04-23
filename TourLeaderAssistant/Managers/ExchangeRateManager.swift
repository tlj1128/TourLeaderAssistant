import Foundation

@MainActor
@Observable
class ExchangeRateManager {
    static let shared = ExchangeRateManager()

    // MARK: - UserDefaults Keys
    private let keyRates = "exchangeRates"
    private let keyLastUpdated = "exchangeRatesLastUpdated"

    // MARK: - State
    private(set) var isLoading = false

    private init() {}

    // MARK: - 取得兩幣種比值
    // 回傳「1 單位 base 幣種 = ? 單位 quote 幣種」
    // 例如 rate(base: "EUR", quote: "CHF") 回傳 0.95
    func rate(base: String, quote: String) -> Double? {
        guard base != quote else { return 1.0 }
        guard let rates = loadCachedRates() else { return nil }

        // Frankfurter 以 TWD 為 base，所有幣種對 TWD 的比值
        // rates["JPY"] = 0.22 代表 1 JPY = 0.22 TWD
        // 要算 1 EUR = ? CHF：先算 1 EUR = ? TWD，再算 ? TWD = ? CHF
        guard let baseToTWD = rates[base],
              let quoteToTWD = rates[quote],
              baseToTWD > 0, quoteToTWD > 0
        else { return nil }

        // 1 base = (baseToTWD / quoteToTWD) quote
        return quoteToTWD / baseToTWD
    }

    // MARK: - 格式化提示文字（支出用）
    // 回傳：「參考匯率：0.95（1 EUR ≈ 0.95 CHF）」
    func expenseRateHint(baseCurrency: String, expenseCurrency: String) -> String? {
        guard baseCurrency != expenseCurrency else { return nil }
        guard let r = rate(base: baseCurrency, quote: expenseCurrency) else { return nil }
        let formatted = String(format: "%.4g", r)
        return "參考匯率：\(formatted)（1 \(baseCurrency) ≈ \(formatted) \(expenseCurrency)）"
    }

    // MARK: - 格式化提示文字（收入用）
    // 回傳：「1 JPY ≈ 0.22 TWD」
    func incomeRateHint(currency: String) -> String? {
        guard currency != "TWD" else { return nil }
        guard let r = rate(base: currency, quote: "TWD") else { return nil }
        let formatted = String(format: "%.4g", r)
        return "1 \(currency) ≈ \(formatted) TWD"
    }

    // MARK: - App 啟動時呼叫，有網路且快取不是今天才更新
    func fetchIfNeeded() async {
        guard !isLoading else { return }
        guard !isTodaysCacheValid() else {
            print("ExchangeRate：快取是今天的，略過更新")
            return
        }
        await fetch()
    }

    // MARK: - 強制更新
    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        // Frankfurter：以 TWD 為 base，取得所有幣種對 TWD 的比值
        guard let url = URL(string: "https://api.frankfurter.dev/v2/rates?base=TWD") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let items = try JSONDecoder().decode([FrankfurterRateItem].self, from: data)

            var rates: [String: Double] = ["TWD": 1.0]
            for item in items {
                rates[item.quote] = item.rate
            }

            saveRates(rates)
            print("ExchangeRate：更新成功，共 \(rates.count) 種幣種")
        } catch {
            print("ExchangeRate：更新失敗：\(error)")
        }
    }
    
    func debugPrintRates() {
        if let rates = loadCachedRates() {
            print("快取匯率筆數：\(rates.count)")
            print("JPY: \(rates["JPY"] ?? 0)")
            print("EUR: \(rates["EUR"] ?? 0)")
        } else {
            print("快取是空的")
        }
    }

    // MARK: - 快取讀寫

    private func isTodaysCacheValid() -> Bool {
        guard let lastUpdated = UserDefaults.standard.object(forKey: keyLastUpdated) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(lastUpdated)
    }

    private func saveRates(_ rates: [String: Double]) {
        UserDefaults.standard.set(rates, forKey: keyRates)
        UserDefaults.standard.set(Date(), forKey: keyLastUpdated)
    }

    private func loadCachedRates() -> [String: Double]? {
        return UserDefaults.standard.dictionary(forKey: keyRates) as? [String: Double]
    }
}

// MARK: - Codable

private struct FrankfurterRateItem: Codable {
    let quote: String
    let rate: Double
}
