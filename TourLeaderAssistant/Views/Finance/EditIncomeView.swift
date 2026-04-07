import SwiftUI
import SwiftData

struct EditIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    let income: Income

    @State private var date: Date
    @State private var type: IncomeType
    @State private var typeCustom: String
    @State private var amount: String
    @State private var currency: String
    @State private var notes: String

    init(income: Income) {
        self.income = income
        _date = State(initialValue: income.date)
        _type = State(initialValue: income.type)
        _typeCustom = State(initialValue: income.typeCustom ?? "")
        _amount = State(initialValue: income.amount.formatted())
        _currency = State(initialValue: income.currency)
        _notes = State(initialValue: income.notes ?? "")
    }

    var isFormValid: Bool {
        !amount.isEmpty &&
        Decimal(string: amount) != nil &&
        !currency.isEmpty &&
        (type != .other || !typeCustom.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_TW"))

                    Picker("類型", selection: $type) {
                        ForEach(IncomeType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }

                    if type == .other {
                        LabeledTextField(label: "自訂名稱", placeholder: "請輸入", text: $typeCustom)
                    }
                }

                Section("金額") {
                    LabeledTextField(label: "金額", placeholder: "5000", text: $amount)
                        .keyboardType(.decimalPad)
                    LabeledTextField(label: "幣種", placeholder: "JPY", text: $currency)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
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
        income.type = type
        income.typeCustom = type == .other ? typeCustom.trimmingCharacters(in: .whitespaces) : nil
        income.amount = amt
        income.currency = currency.uppercased()
        income.notes = notes.isEmpty ? nil : notes
        dismiss()
    }
}
