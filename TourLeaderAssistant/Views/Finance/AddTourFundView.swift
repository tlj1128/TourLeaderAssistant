import SwiftUI
import SwiftData

struct AddTourFundView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let team: Team

    @Query private var allFunds: [TourFund]
    @Query private var allCountries: [Country]
    @Query(sort: \CustomFundType.sortOrder) private var customFundTypes: [CustomFundType]

    var teamFunds: [TourFund] {
        allFunds.filter { $0.teamID == team.id }
    }

    var allTypeNames: [String] {
        DefaultFundType.all.map(\.name)
        + customFundTypes.map(\.name)
        + [DefaultFundType.otherName]
    }

    @State private var selectedTypeName: String = DefaultFundType.all.first?.name ?? "零用金"
    @State private var currency = "TWD"
    @State private var initialAmount = ""
    @State private var isReimbursable = true
    @State private var notes = ""
    @State private var showingCurrencyPicker = false

    var suggestedCurrencies: [String] {
        var result: [String] = []
        if !currency.isEmpty { result.append(currency) }
        for code in team.countryCodes {
            if let country = allCountries.first(where: { $0.code == code }),
               !country.currencyCode.isEmpty,
               !result.contains(country.currencyCode) {
                result.append(country.currencyCode)
            }
        }
        let teamID = team.id
        let recentFund = allFunds
            .filter { $0.teamID == teamID }
            .map { $0.currency }
        for code in recentFund {
            if !result.contains(code) { result.append(code) }
        }
        for common in ["TWD", "USD", "EUR", "JPY", "GBP"] {
            if !result.contains(common) { result.append(common) }
        }
        return Array(result.prefix(8))
    }

    var isFormValid: Bool {
        !initialAmount.isEmpty && Decimal(string: initialAmount) != nil
    }

    var hasPettyCash: Bool {
        teamFunds.contains { $0.typeName == "零用金" }
    }

    var isPettyCashDuplicate: Bool {
        selectedTypeName == "零用金" && hasPettyCash
    }

    var body: some View {
        NavigationStack {
            Form {
                if !teamFunds.isEmpty {
                    Section("已設定的資金") {
                        ForEach(teamFunds) { fund in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(fund.typeName)
                                        .font(.subheadline)
                                    Text(fund.isReimbursable ? "列入報帳" : "不列入報帳")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(fund.currency) \(fund.initialAmount.formatted())")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(teamFunds[index])
                            }
                        }
                    }
                }

                Section("新增資金") {
                    if isPettyCashDuplicate {
                        Text("零用金只能設定一筆")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Picker("類型", selection: $selectedTypeName) {
                        ForEach(allTypeNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    HStack(spacing: 8) {
                        LabeledTextField(label: "金額", placeholder: "10000", text: $initialAmount)
                            .keyboardType(.decimalPad)
                        currencyButton
                    }

                    Toggle("列入報帳", isOn: $isReimbursable)

                    TextField("備註", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("資金紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增") { saveFund() }
                        .disabled(!isFormValid || isPettyCashDuplicate)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let first = suggestedCurrencies.first {
                    currency = first
                }
            }
            .onChange(of: teamFunds) { _, funds in
                let hasPC = funds.contains { $0.typeName == "零用金" }
                if hasPC {
                    selectedTypeName = allTypeNames.first { $0 != "零用金" } ?? DefaultFundType.otherName
                } else {
                    selectedTypeName = "零用金"
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPicker(selectedCurrency: $currency, team: team)
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

    private func saveFund() {
        guard let amt = Decimal(string: initialAmount) else { return }

        let fund = TourFund(
            teamID: team.id,
            typeName: selectedTypeName,
            currency: currency,
            initialAmount: amt,
            isReimbursable: isReimbursable
        )
        fund.notes = notes.isEmpty ? nil : notes

        modelContext.insert(fund)
        try? modelContext.save()

        if hasPettyCash {
            selectedTypeName = allTypeNames.first { $0 != "零用金" } ?? DefaultFundType.otherName
        } else {
            selectedTypeName = "零用金"
        }
        currency = suggestedCurrencies.first ?? "TWD"
        initialAmount = ""
        isReimbursable = true
        notes = ""
    }
}
