import SwiftUI
import SwiftData
import PhotosUI

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let team: Team
    var lastExpense: Expense? = nil

    @Query private var allCountries: [Country]

    @State private var date: Date
    @State private var location: String
    @State private var item = ""
    @State private var quantity = "1"
    @State private var amount = ""
    @State private var currency: String
    @State private var exchangeRate: String
    @State private var receiptNumber = ""
    @State private var paymentMethod: PaymentMethod? = nil
    @State private var notes = ""
    @State private var showingCurrencyPicker = false
    @State private var receiptImages: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @AppStorage("savePhotoToAlbum") private var savePhotoToAlbum = true

    let baseCurrency: String

    init(team: Team, lastExpense: Expense? = nil, baseCurrency: String = "USD") {
        self.team = team
        self.lastExpense = lastExpense
        self.baseCurrency = baseCurrency
        _date = State(initialValue: lastExpense?.date ?? Date())
        _location = State(initialValue: lastExpense?.location ?? "")
        _currency = State(initialValue: lastExpense?.currency ?? "USD")
        _exchangeRate = State(initialValue: lastExpense?.exchangeRate.formatted() ?? "")
    }

    var suggestedCurrencies: [String] {
        var result: [String] = []
        if !currency.isEmpty && !result.contains(currency) {
            result.append(currency)
        }
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
                    HStack(spacing: 8) {
                        LabeledTextField(label: "金額", placeholder: "288", text: $amount, keyboardType: .decimalPad)
                            .onChange(of: amount) { _, newValue in
                                amount = newValue.filter { $0.isNumber || $0 == "." }
                            }
                        currencyButton
                    }

                    LabeledTextField(label: "數量", placeholder: "1", text: $quantity, keyboardType: .decimalPad)
                        .onChange(of: quantity) { _, newValue in
                            quantity = newValue.filter { $0.isNumber || $0 == "." }
                        }
                    LabeledTextField(label: "匯率", placeholder: "15（以零用金為基準）", text: $exchangeRate, keyboardType: .decimalPad)
                        .onChange(of: exchangeRate) { _, newValue in
                            exchangeRate = newValue.filter { $0.isNumber || $0 == "." }
                        }
                    if let hint = ExchangeRateManager.shared.expenseRateHint(baseCurrency: baseCurrency, expenseCurrency: currency) {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }

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

                    Picker("支付方式", selection: $paymentMethod) {
                        Text("未選擇").tag(Optional<PaymentMethod>.none)
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(Optional(method))
                        }
                    }

                    // 收據照片
                    if !receiptImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(receiptImages.indices, id: \.self) { index in
                                    Image(uiImage: receiptImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $pickerItems, matching: .images) {
                            Label("從相簿選取", systemImage: "photo")
                                .font(.subheadline)
                        }
                        .onChange(of: pickerItems) { _, newItems in
                            Task {
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        receiptImages.append(image)
                                    }
                                }
                                pickerItems = []
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider().frame(height: 20)

                        Label("拍照", systemImage: "camera")
                            .font(.subheadline)
                            .foregroundStyle(Color("AppAccent"))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .contentShape(Rectangle())
                            .onTapGesture { showingCamera = true }
                    }
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
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPicker(selectedCurrency: $currency, team: team)
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    receiptImages.append(image)
                    if savePhotoToAlbum {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }
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

    private func loadDefaults() {
        if let last = lastExpense {
            currency = last.currency
        } else if let firstCurrency = suggestedCurrencies.first {
            currency = firstCurrency
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
        expense.paymentMethod = paymentMethod?.rawValue
        expense.notes = notes.isEmpty ? nil : notes

        // 儲存收據照片
        var paths: [String] = []
        for image in receiptImages {
            if let fileName = ReceiptPhotoManager.shared.save(image: image) {
                paths.append(fileName)
            }
        }
        expense.receiptImagePaths = paths

        modelContext.insert(expense)
        dismiss()
    }
}
