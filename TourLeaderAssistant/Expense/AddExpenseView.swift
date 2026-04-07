import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let team: Team

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
                    TextField("地點", text: $location)
                    TextField("花費項目", text: $item)
                }

                Section("金額") {
                    TextField("金額", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("數量", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("幣種（例如 USD）", text: $currency)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    TextField("比值（對應零用金）", text: $exchangeRate)
                        .keyboardType(.decimalPad)

                    if let converted = convertedAmount {
                        HStack {
                            Text("換算金額")
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(converted.formatted())")
                                    .fontWeight(.medium)
                                Text("\(amount) × \(quantity) ÷ \(exchangeRate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("收據") {
                    TextField("收據編號（無收據填 x）", text: $receiptNumber)
                }

                Section("備註") {
                    TextField("備註", text: $notes, axis: .vertical)
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
        }
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
