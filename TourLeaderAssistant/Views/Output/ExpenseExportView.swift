import SwiftUI
import SwiftData

// MARK: - 欄位定義

struct ExportColumnItem: Identifiable {
    let id: String
    let title: String
    var isSelected: Bool
}

extension ExportColumnItem {
    static var defaults: [ExportColumnItem] {
        [
            ExportColumnItem(id: "date",            title: "日期",     isSelected: true),
            ExportColumnItem(id: "location",        title: "地點",     isSelected: true),
            ExportColumnItem(id: "item",            title: "項目",     isSelected: true),
            ExportColumnItem(id: "currency",        title: "幣種",     isSelected: true),
            ExportColumnItem(id: "amount",          title: "金額",     isSelected: true),
            ExportColumnItem(id: "quantity",        title: "數量",     isSelected: true),
            ExportColumnItem(id: "exchangeRate",    title: "匯率",     isSelected: true),
            ExportColumnItem(id: "convertedAmount", title: "換算金額", isSelected: true),
            ExportColumnItem(id: "receiptNumber",   title: "收據編號", isSelected: true),
            ExportColumnItem(id: "notes",           title: "備註",     isSelected: true),
        ]
    }
}

// MARK: - 匯出格式

enum ExportFormat: String, Identifiable {
    case pdf, csv
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pdf: return "匯出 PDF"
        case .csv: return "匯出 CSV"
        }
    }
}

// MARK: - 欄位選擇 Sheet（CSV & PDF 共用）

struct ColumnPickerSheet: View {
    let team: Team
    let expenses: [Expense]
    let funds: [TourFund]
    let leaderName: String
    let exportFormat: ExportFormat
    @Binding var showingPicker: Bool

    @State private var columns: [ExportColumnItem] = ExportColumnItem.defaults
    @State private var isExporting = false

    var selectedCount: Int { columns.filter(\.isSelected).count }

    var mainCurrency: String {
        funds.first(where: { $0.isReimbursable })?.currency ?? "USD"
    }

    var mainExpenses: [Expense] { expenses.filter { $0.currency != "TWD" } }
    var twdExpenses: [Expense] { expenses.filter { $0.currency == "TWD" } }

    var totalConverted: Decimal {
        mainExpenses.reduce(Decimal(0)) { $0 + $1.convertedAmount }
    }

    var totalCarried: Decimal {
        funds.filter { $0.isReimbursable }.reduce(Decimal(0)) { $0 + $1.initialAmount }
    }

    var amountToReturn: Decimal { totalCarried - totalConverted }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($columns) { $col in
                        HStack {
                            Image(systemName: col.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(col.isSelected ? Color("AppAccent") : Color(.systemGray3))
                                .onTapGesture { col.isSelected.toggle() }
                            Text(col.title)
                                .foregroundStyle(col.isSelected ? .primary : .secondary)
                            Spacer()
                        }
                    }
                    .onMove { from, to in
                        columns.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text("選擇欄位並拖拉排序")
                } footer: {
                    Text("已選 \(selectedCount) 個欄位，第一列為欄位名稱")
                }
            }
            .navigationTitle(exportFormat.title)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showingPicker = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isExporting ? "產生中…" : "匯出") {
                        switch exportFormat {
                        case .csv: generateAndShareCSV()
                        case .pdf: generateAndSharePDF()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCount == 0 || isExporting)
                }
            }
        }
    }

    // MARK: - 共用：取欄位值

    private func value(for colID: String, expense: Expense, dateFormatter: DateFormatter) -> String {
        switch colID {
        case "date":            return dateFormatter.string(from: expense.date)
        case "location":        return expense.location ?? ""
        case "item":            return expense.item
        case "currency":        return expense.currency
        case "amount":          return expense.amount.formatted(.number.precision(.fractionLength(2)))
        case "quantity":        return expense.quantity.formatted()
        case "exchangeRate":    return expense.exchangeRate.formatted()
        case "convertedAmount": return expense.convertedAmount.formatted(.number.precision(.fractionLength(2)))
        case "receiptNumber":   return expense.receiptNumber?.isEmpty == false ? expense.receiptNumber! : "x"
        case "notes":           return expense.notes ?? ""
        default:                return ""
        }
    }

    // MARK: - CSV

    private func generateAndShareCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let selectedCols = columns.filter(\.isSelected)

        var rows: [[String]] = []
        rows.append(selectedCols.map { $0.title })
        for expense in expenses {
            rows.append(selectedCols.map { col in
                csvEscape(value(for: col.id, expense: expense, dateFormatter: dateFormatter))
            })
        }

        let csvString = rows.map { $0.joined(separator: ",") }.joined(separator: "\n")
        let bom = "\u{FEFF}"
        let fileName = "\(team.name)_報帳單.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? (bom + csvString).write(to: url, atomically: true, encoding: .utf8)
        presentActivity(items: [url])
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // MARK: - PDF

    private func generateAndSharePDF() {
        isExporting = true
        Task {
            let url = await buildPDF()
            await MainActor.run {
                isExporting = false
                presentActivity(items: [url])
            }
        }
    }

    private func buildPDF() async -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let selectedCols = columns.filter(\.isSelected)

        let headerCells = selectedCols.map { "<th>\($0.title)</th>" }.joined()

        var mainRows = ""
        for (i, expense) in mainExpenses.enumerated() {
            let bg = i % 2 == 0 ? "#f2f2f2" : "#ffffff"
            let cells = selectedCols.map { col in
                let v = value(for: col.id, expense: expense, dateFormatter: dateFormatter)
                let align = ["amount","quantity","exchangeRate","convertedAmount"].contains(col.id) ? " class=\"num\"" : ""
                return "<td\(align)>\(v)</td>"
            }.joined()
            mainRows += "<tr style=\"background:\(bg)\">\(cells)</tr>\n"
        }

        var twdSection = ""
        if !twdExpenses.isEmpty {
            var twdRows = ""
            for (i, expense) in twdExpenses.enumerated() {
                let bg = i % 2 == 0 ? "#f2f2f2" : "#ffffff"
                twdRows += """
                <tr style="background:\(bg)">
                    <td>\(expense.item)</td>
                    <td class="num">\(expense.amount.formatted(.number.precision(.fractionLength(0))))</td>
                    <td>\(expense.receiptNumber?.isEmpty == false ? expense.receiptNumber! : "x")</td>
                    <td>\(expense.notes ?? "")</td>
                </tr>
                """
            }
            twdSection = """
            <div class="section-box">
                <div class="section-title">台幣項目</div>
                <table>
                    <thead><tr><th>項目</th><th>金額 (TWD)</th><th>收據編號</th><th>備註</th></tr></thead>
                    <tbody>\(twdRows)</tbody>
                </table>
            </div>
            """
        }

        var fundRows = ""
        for (i, fund) in funds.enumerated() {
            let bg = i % 2 == 0 ? "#f2f2f2" : "#ffffff"
            fundRows += """
            <tr style="background:\(bg)">
                <td>\(fund.typeName)</td>
                <td class="num">\(fund.initialAmount.formatted(.number.precision(.fractionLength(2))))</td>
            </tr>
            """
        }
        let fundSection = """
        <div class="section-box">
            <div class="section-title">攜出金額明細</div>
            <table>
                <thead><tr><th>項目</th><th>金額</th></tr></thead>
                <tbody>\(fundRows)</tbody>
                <tfoot><tr>
                    <td><strong>合計</strong></td>
                    <td class="num"><strong>\(totalCarried.formatted(.number.precision(.fractionLength(2)))) \(mainCurrency)</strong></td>
                </tr></tfoot>
            </table>
        </div>
        """

        let html = buildHTML(
            headerCells: headerCells,
            mainRows: mainRows,
            twdSection: twdSection,
            fundSection: fundSection,
            dateFormatter: dateFormatter
        )

        let fileName = "\(team.name)_報帳單.pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        await MainActor.run {
            let formatter = UIMarkupTextPrintFormatter(markupText: html)
            formatter.perPageContentInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
            let renderer = UIPrintPageRenderer()
            renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
            let pageSize = CGSize(width: 595, height: 842)
            let printableRect = CGRect(x: 36, y: 36, width: 523, height: 770)
            renderer.setValue(NSValue(cgRect: CGRect(origin: .zero, size: pageSize)), forKey: "paperRect")
            renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: pageSize), nil)
            for i in 0..<renderer.numberOfPages {
                UIGraphicsBeginPDFPage()
                renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
            }
            UIGraphicsEndPDFContext()
            try? pdfData.write(to: outputURL)
        }

        return outputURL
    }

    // MARK: - 共用：呈現分享

    private func presentActivity(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - HTML

    private func buildHTML(headerCells: String, mainRows: String, twdSection: String, fundSection: String, dateFormatter: DateFormatter) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body { font-family: Arial, "Heiti TC", sans-serif; font-size: 10px; color: #000; padding: 16px; }
            h1 { font-size: 16px; text-align: center; background: #404040; color: #fff; padding: 8px; margin-bottom: 4px; }
            .info-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 2px; margin-bottom: 8px; }
            .info-item { display: flex; }
            .info-label { background: #808080; color: #fff; font-weight: bold; padding: 3px 6px; min-width: 80px; font-size: 9px; }
            .info-value { background: #d9d9d9; padding: 3px 6px; flex: 1; font-size: 9px; }
            table { width: 100%; border-collapse: collapse; margin-bottom: 6px; font-size: 9px; }
            th { background: #808080; color: #fff; padding: 4px 3px; text-align: center; border: 1px solid #999; }
            td { padding: 3px; border: 1px solid #ccc; }
            .num { text-align: right; }
            tfoot td { background: #bfbfbf; font-weight: bold; }
            .totals { margin: 6px 0; }
            .total-row { display: flex; margin-bottom: 2px; }
            .total-label { background: #808080; color: #fff; font-weight: bold; padding: 3px 8px; font-size: 9px; flex: 1; text-align: right; }
            .total-value { background: #fff; padding: 3px 8px; font-size: 10px; font-weight: bold; min-width: 80px; text-align: right; }
            .bottom-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; margin-top: 8px; }
            .section-box { border: 1px solid #ccc; }
            .section-title { background: #808080; color: #fff; font-weight: bold; padding: 3px 6px; font-size: 9px; }
            .sign-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 4px; margin-top: 8px; }
            .sign-box { border: 1px solid #999; }
            .sign-label { background: #808080; color: #fff; text-align: center; padding: 2px; font-size: 9px; font-weight: bold; }
            .sign-space { height: 30px; background: #f2f2f2; }
        </style>
        </head>
        <body>
        <h1>ESCORT EXPENSES REPORT　領隊報帳單</h1>

        <div class="info-grid">
            <div class="info-item"><div class="info-label">團號</div><div class="info-value">\(team.tourCode)</div></div>
            <div class="info-item"><div class="info-label">出團日期</div><div class="info-value">\(dateFormatter.string(from: team.departureDate))</div></div>
            <div class="info-item"><div class="info-label">領隊</div><div class="info-value">\(leaderName)</div></div>
            <div class="info-item"><div class="info-label">團名</div><div class="info-value">\(team.name)</div></div>
            <div class="info-item"><div class="info-label">出團人數</div><div class="info-value">\(team.paxCount.map { "\($0) 人" } ?? "")</div></div>
            <div class="info-item"><div class="info-label">房間數</div><div class="info-value">\(team.roomCount ?? "")</div></div>
            <div class="info-item"><div class="info-label">匯率基準</div><div class="info-value">\(mainCurrency)</div></div>
            <div class="info-item"><div class="info-label">零用金</div><div class="info-value">\(totalCarried.formatted(.number.precision(.fractionLength(2)))) \(mainCurrency)</div></div>
        </div>

        <table>
            <thead><tr>\(headerCells)</tr></thead>
            <tbody>\(mainRows)</tbody>
        </table>

        <div class="totals">
            <div class="total-row">
                <div class="total-label">當地支出總金額 Total Expenses</div>
                <div class="total-value">\(totalConverted.formatted(.number.precision(.fractionLength(2)))) \(mainCurrency)</div>
            </div>
            <div class="total-row">
                <div class="total-label">攜出總金額 Petty Cash Carried</div>
                <div class="total-value">\(totalCarried.formatted(.number.precision(.fractionLength(2)))) \(mainCurrency)</div>
            </div>
            <div class="total-row">
                <div class="total-label">應繳回金額 Amount to Return</div>
                <div class="total-value">\(amountToReturn.formatted(.number.precision(.fractionLength(2)))) \(mainCurrency)</div>
            </div>
        </div>

        <div class="bottom-grid">
            <div class="section-box">
                <div class="section-title">注意事項</div>
                <div style="padding:4px; font-size:8px; line-height:1.4;">
                    1. 回國後請於三天內連同報告書、旅客意見調查表一併繳交至承辦OP處。<br>
                    2. 代墊款項將於報帳後7天內匯款或現金交予領隊。<br>
                    3. 金額計算一律以四捨五入制執行。
                </div>
            </div>
            \(twdExpenses.isEmpty ? "<div></div>" : twdSection)
            \(fundSection)
        </div>

        <div class="sign-grid">
            <div class="sign-box"><div class="sign-label">會計 Accountant</div><div class="sign-space"></div></div>
            <div class="sign-box"><div class="sign-label">部門主管 Manager</div><div class="sign-space"></div></div>
            <div class="sign-box"><div class="sign-label">經辦 Operator</div><div class="sign-space"></div></div>
            <div class="sign-box"><div class="sign-label">領隊 Escort</div><div class="sign-space"></div></div>
        </div>

        </body>
        </html>
        """
    }
}

// MARK: - ExpenseExportView

struct ExpenseExportView: View {
    let team: Team
    @Query private var expenses: [Expense]
    @Query private var funds: [TourFund]

    @AppStorage("profile_nameZH") private var leaderName = ""
    @State private var activeFormat: ExportFormat = .pdf
    @State private var showingPicker = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    init(team: Team) {
        self.team = team
        let teamID = team.id
        self._expenses = Query(
            filter: #Predicate<Expense> { $0.teamID == teamID },
            sort: [SortDescriptor(\Expense.date), SortDescriptor(\Expense.createdAt)]
        )
        self._funds = Query(
            filter: #Predicate<TourFund> { $0.teamID == teamID }
        )
    }

    var mainExpenses: [Expense] { expenses.filter { $0.currency != "TWD" } }
    var twdExpenses: [Expense] { expenses.filter { $0.currency == "TWD" } }
    var mainCurrency: String { funds.first(where: { $0.isReimbursable })?.currency ?? "USD" }

    var totalConverted: Decimal {
        mainExpenses.reduce(Decimal(0)) { $0 + $1.convertedAmount }
    }

    var totalCarried: Decimal {
        funds.filter { $0.isReimbursable }.reduce(Decimal(0)) { $0 + $1.initialAmount }
    }

    var amountToReturn: Decimal { totalCarried - totalConverted }

    var body: some View {
        NavigationStack {
            List {
                Section("團體資訊") {
                    LabeledContent("團名", value: team.name)
                    LabeledContent("團號", value: team.tourCode)
                    LabeledContent("出發日期", value: team.departureDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("領隊", value: leaderName.isEmpty ? "未設定" : leaderName)
                    if let pax = team.paxCount {
                        LabeledContent("人數", value: "\(pax) 人")
                    }
                }

                Section("帳務摘要") {
                    LabeledContent("主幣種", value: mainCurrency)
                    LabeledContent("支出總計", value: "\(mainCurrency) \(totalConverted.formatted(.number.precision(.fractionLength(2))))")
                    LabeledContent("攜出總金額", value: "\(mainCurrency) \(totalCarried.formatted(.number.precision(.fractionLength(2))))")
                    LabeledContent("應繳回", value: "\(mainCurrency) \(amountToReturn.formatted(.number.precision(.fractionLength(2))))")
                    if !twdExpenses.isEmpty {
                        LabeledContent("台幣項目", value: "\(twdExpenses.count) 筆")
                    }
                }

                Section {
                    HStack(spacing: 0) {
                        Label("匯出 PDF", systemImage: "doc.richtext")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(expenses.isEmpty ? Color(.systemGray3) : Color("AppAccent"))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !expenses.isEmpty {
                                    activeFormat = .pdf
                                    showingPicker = true
                                }
                            }

                        Divider().frame(height: 24)

                        Label("匯出 CSV", systemImage: "tablecells")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(expenses.isEmpty ? Color(.systemGray3) : Color("AppAccent"))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !expenses.isEmpty {
                                    activeFormat = .csv
                                    showingPicker = true
                                }
                            }
                    }
                }
            }
            .navigationTitle("報帳單")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingPicker) {
            ColumnPickerSheet(
                team: team,
                expenses: expenses,
                funds: funds,
                leaderName: leaderName,
                exportFormat: activeFormat,
                showingPicker: $showingPicker
            )
            .appDynamicTypeSize(textSizePreference)
        }
    }
}
