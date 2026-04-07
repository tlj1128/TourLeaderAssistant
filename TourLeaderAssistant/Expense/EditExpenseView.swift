import SwiftUI
import SwiftData

struct EditExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var expense: Expense

    @State private var date: Date
    @State private var location: String
    @State private var item: String
    @State private var quantity: String
    @State private var amount: String
    @State private var currency: String
    @State private var exchangeRate: String
    @State private var receiptNumber: String
    @State private var notes: String

    init(expense: Expense) {
        self.expense = expense
        _date = State(initialValue: expense.date)
        _location = State(initialValue: expense.location ?? "")
        _item = State(initialValue: expense.item)
        _quantity = State(initialValue: expense.quantity.formatted())
        _amount = State(initialValue: expense.amount.formatted())
        _currency = State(initialValue: expense.currency)
        _exchangeRate = State(initialValue: expense.exchangeRate.formatted())
        _receiptNumber = State(initialValue: expense.receiptNumber ?? "")
        _notes = State(initialValue: expense.notes ?? "")
    }

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
            .navigationTitle("編輯支出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") { saveChanges() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveChanges() {
        guard
            let amt = Decimal(string: amount),
            let qty = Decimal(string: quantity),
            let rate = Decimal(string: exchangeRate)
        else { return }

        expense.date = date
        expense.location = location.isEmpty ? nil : location
        expense.item = item
        expense.quantity = qty
        expense.amount = amt
        expense.currency = currency
        expense.exchangeRate = rate
        expense.convertedAmount = (amt * qty) / rate
        expense.receiptNumber = receiptNumber.isEmpty ? nil : receiptNumber
        expense.notes = notes.isEmpty ? nil : notes

        dismiss()
    }
}
