import SwiftUI
import SwiftData

// MARK: - 幣種資料

// 從 SeedData 整理出來的幣種清單，按地區分組
// 去重後保留第一個出現的地區
struct CurrencyData {

    static let regions: [(name: String, codes: [String])] = [
        ("東亞", ["TWD", "JPY", "KRW", "CNY", "HKD", "MOP", "MNT"]),
        ("東南亞", ["THB", "VND", "SGD", "MYR", "IDR", "PHP", "MMK", "KHR", "LAK", "BND"]),
        ("南亞", ["INR", "NPR", "LKR", "BTN", "BDT", "MVR", "PKR"]),
        ("中亞", ["KZT", "UZS", "KGS", "TJS", "TMT"]),
        ("西亞", ["TRY", "ILS", "JOD", "LBP", "SYP", "IQD", "IRR", "SAR", "AED", "QAR", "KWD", "BHD", "OMR", "YER", "GEL", "AMD", "AZN", "AFN"]),
        ("北歐", ["SEK", "NOK", "DKK", "ISK"]),
        ("西歐", ["EUR", "GBP", "CHF"]),
        ("東歐", ["RUB", "UAH", "BYN", "MDL", "PLN", "CZK", "HUF", "RON", "BGN"]),
        ("南歐", ["ALL", "MKD", "BAM", "RSD"]),
        ("北非", ["MAD", "DZD", "TND", "LYD", "EGP", "SDG"]),
        ("東非", ["ETB", "KES", "TZS", "UGX", "RWF", "BIF", "ZMW", "ZWL", "MGA", "MUR", "SCR", "KMF"]),
        ("中非", ["XAF", "CDF"]),
        ("西非", ["GHS", "XOF", "NGN", "CVE", "GMD", "GNF", "SLL", "LRD", "MRU"]),
        ("南非地區", ["ZAR", "NAD", "BWP", "MZN", "SZL", "LSL", "AOA", "MWK"]),
        ("北美", ["USD", "CAD"]),
        ("中美洲", ["MXN", "GTQ", "BZD", "HNL", "NIO", "CRC", "PAB"]),
        ("加勒比海", ["CUP", "JMD", "DOP", "BSD", "TTD", "BBD", "XCD", "AWG", "HTG"]),
        ("南美洲", ["BRL", "ARS", "CLP", "PEN", "COP", "BOB", "PYG", "UYU", "VES", "GYD", "SRD"]),
        ("大洋洲", ["AUD", "NZD", "FJD", "VUV", "PGK", "SBD", "WST", "TOP", "XPF"]),
    ]

    // 從 SeedData 建立幣種 → 國家對應表（中英文）
    static let codeToCountries: [String: [(nameZH: String, nameEN: String)]] = {
        var dict: [String: [(nameZH: String, nameEN: String)]] = [:]
        for item in SeedData.countries {
            let code = item.4 // currencyCode
            if !dict[code.isEmpty ? "USD" : code, default: []].contains(where: { $0.nameZH == item.0 }) {
                dict[code, default: []].append((nameZH: item.0, nameEN: item.1))
            }
        }
        return dict
    }()

    // 所有不重複幣種代碼
    static let allCodes: [String] = {
        regions.flatMap { $0.codes }
    }()
}

// MARK: - CurrencyPicker

struct CurrencyPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: String

    let team: Team

    @Query private var allCountries: [Country]
    @Query private var allExpenses: [Expense]
    @Query private var allIncomes: [Income]
    @Query private var allFunds: [TourFund]

    @State private var searchText = ""

    // MARK: 優先幣種

    private var destinationCurrencies: [String] {
        var result: [String] = []
        for code in team.countryCodes {
            if let country = allCountries.first(where: { $0.code == code }),
               !country.currencyCode.isEmpty,
               !result.contains(country.currencyCode) {
                result.append(country.currencyCode)
            }
        }
        return result
    }

    private var recentCurrencies: [String] {
        let teamID = team.id
        var seen: [String] = []
        let expenseCurrencies = allExpenses
            .filter { $0.teamID == teamID }
            .sorted { $0.date > $1.date }
            .map { $0.currency }
        let incomeCurrencies = allIncomes
            .filter { $0.teamID == teamID }
            .sorted { $0.date > $1.date }
            .map { $0.currency }
        let fundCurrencies = allFunds
            .filter { $0.teamID == teamID }
            .map { $0.currency }
        for code in expenseCurrencies + incomeCurrencies + fundCurrencies {
            if !seen.contains(code) { seen.append(code) }
        }
        return seen
    }

    private let commonCurrencies = ["TWD", "USD", "EUR", "JPY", "GBP"]

    private var priorityCurrencies: [String] {
        var result: [String] = []
        for code in destinationCurrencies + recentCurrencies + commonCurrencies {
            if !result.contains(code) { result.append(code) }
        }
        return result
    }

    // MARK: 搜尋

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var searchResults: [String] {
        let q = searchText.trimmingCharacters(in: .whitespaces).uppercased()
        return CurrencyData.allCodes.filter { code in
            if code.contains(q) { return true }
            if let countries = CurrencyData.codeToCountries[code] {
                return countries.contains {
                    $0.nameZH.contains(searchText) || $0.nameEN.uppercased().contains(q)
                }
            }
            return false
        }
    }

    // MARK: 完整清單（排除優先區已有的）

    private var fullListRegions: [(name: String, codes: [String])] {
        CurrencyData.regions.compactMap { region in
            let filtered = region.codes.filter { !priorityCurrencies.contains($0) }
            return filtered.isEmpty ? nil : (region.name, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    searchSection
                } else {
                    prioritySection
                    fullListSection
                }
            }
            .navigationTitle("選擇幣種")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "幣種代碼、國家名稱")
        }
    }

    // MARK: - 搜尋結果

    private var searchSection: some View {
        Section {
            if searchResults.isEmpty {
                Text("沒有符合的幣種")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(searchResults, id: \.self) { code in
                    currencyRow(code: code)
                }
            }
        }
    }

    // MARK: - 優先區

    private var prioritySection: some View {
        Section("常用與目的地") {
            ForEach(priorityCurrencies, id: \.self) { code in
                currencyRow(code: code)
            }
        }
    }

    // MARK: - 完整清單

    private var fullListSection: some View {
        ForEach(fullListRegions, id: \.name) { region in
            Section(region.name) {
                ForEach(region.codes, id: \.self) { code in
                    currencyRow(code: code)
                }
            }
        }
    }

    // MARK: - 幣種列

    private func currencyRow(code: String) -> some View {
        let countries = CurrencyData.codeToCountries[code] ?? []
        let countryNames = countries.prefix(3).map { $0.nameZH }.joined(separator: "、")

        return Button {
            selectedCurrency = code
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text(code)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, alignment: .leading)
                if !countryNames.isEmpty {
                    Text(countryNames)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if code == selectedCurrency {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color("AppAccent"))
                        .fontWeight(.semibold)
                }
            }
        }
        .listRowBackground(Color("AppCard"))
    }
}
