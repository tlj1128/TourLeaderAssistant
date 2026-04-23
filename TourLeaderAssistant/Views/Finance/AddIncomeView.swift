import SwiftUI
import SwiftData

struct AddIncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let team: Team

    @Query private var allCountries: [Country]
    @Query(sort: \CustomIncomeType.sortOrder) private var customIncomeTypes: [CustomIncomeType]

    // 預設 + 自訂 + 其他
    var allTypeNames: [String] {
        DefaultIncomeType.all.map(\.name)
        + customIncomeTypes.map(\.name)
        + [DefaultIncomeType.otherName]
    }

    @State private var date = Date()
    @State private var selectedTypeName: String = DefaultIncomeType.all.first?.name ?? "領隊小費"
    @State private var amount = ""
    @State private var currency = "TWD"
    @State private var notes = ""

    var suggestedCurrencies: [String] {
        var result: [String] = []
        for code in team.countryCodes {
            if let country = allCountries.first(where: { $0.code == code }),
               !country.currencyCode.isEmpty,
               !result.contains(country.currencyCode) {
                result.append(country.currencyCode)
            }
        }
        for common in ["TWD", "USD", "EUR", "JPY", "GBP"] {
            if !result.contains(common) { result.append(common) }
        }
        return result
    }

    var isFormValid: Bool {
        !amount.isEmpty && Decimal(string: amount) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_TW"))

                    Picker("類型", selection: $selectedTypeName) {
                        ForEach(allTypeNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }

                Section("金額") {
                    HStack(spacing: 8) {
                        LabeledTextField(label: "金額", placeholder: "5000", text: $amount)
                            .keyboardType(.decimalPad)
                        Picker("", selection: $currency) {
                            ForEach(suggestedCurrencies, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(Color("AppAccent"))
                    }
                    if let hint = ExchangeRateManager.shared.incomeRateHint(currency: currency) {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }

                Section("備註") {
                    TextField("選填", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("新增收入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") { save() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let first = suggestedCurrencies.first {
                    currency = first
                }
            }
        }
    }

    private func save() {
        guard let amt = Decimal(string: amount) else { return }

        let income = Income(
            teamID: team.id,
            date: date,
            typeName: selectedTypeName,
            amount: amt,
            currency: currency
        )
        income.notes = notes.isEmpty ? nil : notes

        modelContext.insert(income)
        dismiss()
    }
}
