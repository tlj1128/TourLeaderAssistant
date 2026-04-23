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

    // 預設 + 自訂 + 其他
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
                        Picker("", selection: $currency) {
                            ForEach(suggestedCurrencies, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(Color("AppAccent"))
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
