import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var paymentMethod: PaymentMethod?
    @State private var notes: String
    @State private var showingCurrencyPicker = false
    @State private var receiptImages: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @AppStorage("savePhotoToAlbum") private var savePhotoToAlbum = true

    @Query private var allFunds: [TourFund]
    @Query private var allExpenses: [Expense]
    @Query private var allCountries: [Country]

    var baseCurrency: String {
        let teamID = expense.teamID
        return allFunds
            .filter { $0.teamID == teamID && $0.isReimbursable }
            .max(by: { $0.initialAmount < $1.initialAmount })?
            .currency ?? "USD"
    }

    // 用 teamID 找到這個團，抓目的地國家幣種
    var teamCountryCodes: [String] {
        // EditExpenseView 沒有 team，從已有支出推算 teamID 即可
        // 國家幣種從 allCountries 配合 allFunds 的 teamID 查不到 countryCodes
        // 改為從 allExpenses 抓最近使用的幣種
        []
    }

    var suggestedCurrencies: [String] {
        var result: [String] = []
        // 當前幣種排最前
        if !currency.isEmpty { result.append(currency) }
        // 本團最近使用的幣種
        let teamID = expense.teamID
        let recent = allExpenses
            .filter { $0.teamID == teamID }
            .sorted { $0.date > $1.date }
            .map { $0.currency }
        for code in recent {
            if !result.contains(code) { result.append(code) }
        }
        // 常用幣種
        for common in ["TWD", "USD", "EUR", "JPY", "GBP"] {
            if !result.contains(common) { result.append(common) }
        }
        return Array(result.prefix(8))
    }

    // EditExpenseView 沒有 team，建一個假的 team 傳給 CurrencyPicker 不合適
    // 改用 teamID 讓 CurrencyPicker 自己查
    @Query private var allTeams: [Team]
    var team: Team? {
        allTeams.first { $0.id == expense.teamID }
    }

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
        _paymentMethod = State(initialValue: PaymentMethod(rawValue: expense.paymentMethod ?? ""))
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
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: receiptImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Button {
                                            // 刪除本機檔案
                                            if index < expense.receiptImagePaths.count {
                                                ReceiptPhotoManager.shared.delete(fileName: expense.receiptImagePaths[index])
                                            }
                                            receiptImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(Color.white, Color(.systemGray))
                                                .font(.title3)
                                        }
                                        .offset(x: 6, y: -6)
                                    }
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
            .navigationTitle("編輯支出")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                receiptImages = expense.receiptImagePaths.compactMap {
                    ReceiptPhotoManager.shared.loadImage(fileName: $0)
                }
            }
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
            .sheet(isPresented: $showingCurrencyPicker) {
                if let t = team {
                    CurrencyPicker(selectedCurrency: $currency, team: t)
                }
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
        expense.paymentMethod = paymentMethod?.rawValue
        expense.notes = notes.isEmpty ? nil : notes

        // 重新儲存所有照片（簡單策略：清除舊檔，重新存入現有的）
        // 已在 UI 刪除的照片在刪除時就已刪本機檔案
        // 這裡只處理新增的照片（尚未存過的）
        let existingPaths = Set(expense.receiptImagePaths)
        var newPaths: [String] = []
        let existingImages = existingPaths.compactMap { ReceiptPhotoManager.shared.loadImage(fileName: $0) }
        _ = existingImages // 已有的照片路徑保留

        // 重新建立路徑列表：保留現有路徑 + 新增的照片
        var updatedPaths = expense.receiptImagePaths.filter { path in
            ReceiptPhotoManager.shared.loadImage(fileName: path) != nil
        }
        // 新增的照片（receiptImages 比 updatedPaths 多的部分）
        let existingCount = updatedPaths.count
        for i in existingCount..<receiptImages.count {
            if let fileName = ReceiptPhotoManager.shared.save(image: receiptImages[i]) {
                newPaths.append(fileName)
            }
        }
        expense.receiptImagePaths = updatedPaths + newPaths

        dismiss()
    }
}
