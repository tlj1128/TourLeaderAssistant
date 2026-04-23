import SwiftUI
import SwiftData

struct EditIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    let income: Income

    @Query(sort: \CustomIncomeType.sortOrder) private var customIncomeTypes: [CustomIncomeType]

    @State private var date: Date
    @State private var selectedTypeName: String
    @State private var amount: String
    @State private var currency: String
    @State private var notes: String

    let commonCurrencies = ["TWD", "USD", "EUR", "JPY", "GBP", "HKD", "AUD", "SGD", "KRW", "THB"]

    init(income: Income) {
        self.income = income
        _date = State(initialValue: income.date)
        _selectedTypeName = State(initialValue: income.typeName)
        _amount = State(initialValue: income.amount.formatted())
        _currency = State(initialValue: income.currency)
        _notes = State(initialValue: income.notes ?? "")
    }

    // 預設 + 自訂 + 其他
    var allTypeNames: [String] {
        DefaultIncomeType.all.map(\.name)
        + customIncomeTypes.map(\.name)
        + [DefaultIncomeType.otherName]
    }

    var currencyOptions: [String] {
        var result = commonCurrencies
        if !result.contains(currency) { result.insert(currency, at: 0) }
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
                            ForEach(currencyOptions, id: \.self) { code in
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
            .navigationTitle("編輯收入")
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
        }
    }

    private func save() {
        guard let amt = Decimal(string: amount) else { return }
        income.date = date
        income.typeName = selectedTypeName
        income.amount = amt
        income.currency = currency
        income.notes = notes.isEmpty ? nil : notes
        dismiss()
    }
}
