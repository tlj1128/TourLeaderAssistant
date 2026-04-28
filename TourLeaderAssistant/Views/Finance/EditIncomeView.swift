import SwiftUI
import SwiftData

struct EditIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    let income: Income

    @Query(sort: \CustomIncomeType.sortOrder) private var customIncomeTypes: [CustomIncomeType]
    @Query private var allIncomes: [Income]
    @Query private var allTeams: [Team]

    @State private var date: Date
    @State private var selectedTypeName: String
    @State private var amount: String
    @State private var currency: String
    @State private var notes: String
    @State private var showingCurrencyPicker = false

    init(income: Income) {
        self.income = income
        _date = State(initialValue: income.date)
        _selectedTypeName = State(initialValue: income.typeName)
        _amount = State(initialValue: income.amount.formatted())
        _currency = State(initialValue: income.currency)
        _notes = State(initialValue: income.notes ?? "")
    }

    var team: Team? {
        allTeams.first { $0.id == income.teamID }
    }

    var allTypeNames: [String] {
        DefaultIncomeType.all.map(\.name)
        + customIncomeTypes.map(\.name)
        + [DefaultIncomeType.otherName]
    }

    var suggestedCurrencies: [String] {
        var result: [String] = []
        if !currency.isEmpty { result.append(currency) }
        let teamID = income.teamID
        let recent = allIncomes
            .filter { $0.teamID == teamID }
            .sorted { $0.date > $1.date }
            .map { $0.currency }
        for code in recent {
            if !result.contains(code) { result.append(code) }
        }
        for common in ["TWD", "USD", "EUR", "JPY", "GBP"] {
            if !result.contains(common) { result.append(common) }
        }
        return Array(result.prefix(8))
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
                        currencyButton
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
            .sheet(isPresented: $showingCurrencyPicker) {
                if let t = team {
                    CurrencyPicker(selectedCurrency: $currency, team: t)
                }
            }
        }
    }

    // MARK: - 幣種按鈕

    @ViewBuilder
    private var currencyButton: some View {
        if AppConfigManager.shared.isCurrencyPickerEnabled {
            Menu {
                ForEach(suggestedCurrencies, id: \.self) { code in
                    Button {
                        currency = code
                    } label: {
                        if code == currency {
                            Label(code, systemImage: "checkmark")
                        } else {
                            Text(code)
                        }
                    }
                }
                Divider()
                Button {
                    showingCurrencyPicker = true
                } label: {
                    Label("更多幣種…", systemImage: "magnifyingglass")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currency)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color("AppAccent"))
            }
        } else {
            Picker("", selection: $currency) {
                ForEach(suggestedCurrencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Color("AppAccent"))
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
