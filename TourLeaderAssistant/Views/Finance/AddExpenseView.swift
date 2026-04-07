import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let team: Team
    var lastExpense: Expense? = nil

    @State private var date = Date()
    @State private var location = ""
    @State private var item = ""
    @State private var quantity = "1"
    @State private var amount = ""
    @State private var currency = "USD"
    @State private var exchangeRate = ""
    @State private var receiptNumber = ""
    @State private var notes = ""

    var convertedAmount: Decimal? {
        guard
            let amt = Decimal(string: amount),
            let qty = Decimal(string: quantity),
            let rate = Decimal(string: exchangeRate),
            rate != 0
        else { return nil }
        return (amt * qty) / rate
    }

    var isFormValid: Bool {
        !item.isEmpty &&
        !amount.isEmpty &&
        !quantity.isEmpty &&
        !exchangeRate.isEmpty &&
        convertedAmount != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_TW"))
                    LabeledTextField(label: "地點", placeholder: "Windhoek", text: $location)
                    LabeledTextField(label: "項目", placeholder: "午餐酒水", text: $item)
                }

                Section("金額") {
                    LabeledTextField(label: "金額", placeholder: "288", text: $amount)
                        .keyboardType(.decimalPad)
                    LabeledTextField(label: "數量", placeholder: "1", text: $quantity)
                        .keyboardType(.decimalPad)
                    LabeledTextField(label: "幣種", placeholder: "USD", text: $currency)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    LabeledTextField(label: "匯率", placeholder: "15（以零用金為基準）", text: $exchangeRate)
                        .keyboardType(.decimalPad)

                    if let converted = convertedAmount {
                        HStack {
                            Text("換算金額")
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(converted.formatted(.number.precision(.fractionLength(2))))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color("AppAccent"))
                                Text("\(amount) × \(quantity) ÷ \(exchangeRate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("收據") {
                    LabeledTextField(label: "收據編號", placeholder: "選填", text: $receiptNumber)
                }

                Section("備註") {
                    TextField("選填", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("新增支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") { saveExpense() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadDefaults() }
        }
    }

    private func loadDefaults() {
        guard let last = lastExpense else { return }
        date = last.date
        location = last.location ?? ""
        currency = last.currency
        exchangeRate = last.exchangeRate.formatted()
    }

    private func saveExpense() {
        guard
            let amt = Decimal(string: amount),
            let qty = Decimal(string: quantity),
            let rate = Decimal(string: exchangeRate)
        else { return }

        let expense = Expense(
            teamID: team.id,
            item: item,
            quantity: qty,
            amount: amt,
            currency: currency,
            exchangeRate: rate,
            date: date
        )
        expense.location = location.isEmpty ? nil : location
        expense.receiptNumber = receiptNumber.isEmpty ? nil : receiptNumber
        expense.notes = notes.isEmpty ? nil : notes

        modelContext.insert(expense)
        dismiss()
    }
}
