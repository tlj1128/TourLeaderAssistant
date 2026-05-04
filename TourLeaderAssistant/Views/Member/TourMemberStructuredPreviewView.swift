import SwiftUI

// iOS 26 RecognizeDocumentsRequest 結果專屬預覽視圖
// 設計：1 Vision row = 1 RawTable row，cell 內保留 \n。
// 多行內容（護照三行 / 地址備註多行）由 mapper 透過 field type 自行拆解
// （.passportFull / .nameENZH / .remark 等）。畫面上 cell 直接以多行顯示。

struct TourMemberStructuredPreviewView: View {
    let team: Team
    let result: StructuredOCRTable
    let onMapped: ([ParsedMember]) -> Void

    @State private var dataStartRow: Int = 1
    @State private var dataEndRow: Int = 1
    @State private var columnMappings: [ColumnMapping] = []
    @State private var previewMembers: [ParsedMember] = []

    private var table: RawTable { result.table.normalized() }
    private var maxColumns: Int { table.maxColumnCount }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                // ── 原始資料預覽 ──
                Section {
                    ScrollView(.horizontal, showsIndicators: true) {
                        rawTableView.padding(.vertical, 4)
                    }
                    .listRowBackground(Color("AppCard"))
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                } header: {
                    sectionHeader(icon: "doc.text",
                                  title: "原始資料（共 \(table.rowCount) 列，每列 1 位團員）")
                }

                // ── 資料範圍 ──
                Section {
                    Stepper("從第 \(dataStartRow) 列開始",
                            value: $dataStartRow,
                            in: 1...max(1, table.rowCount))
                    .listRowBackground(Color("AppCard"))
                    .onChange(of: dataStartRow) { _, _ in updatePreview() }

                    Stepper("到第 \(dataEndRow) 列結束",
                            value: $dataEndRow,
                            in: dataStartRow...max(dataStartRow, table.rowCount))
                    .listRowBackground(Color("AppCard"))
                    .onChange(of: dataEndRow) { _, _ in updatePreview() }
                } header: {
                    sectionHeader(icon: "slider.horizontal.3", title: "資料範圍")
                } footer: {
                    Text("跳過表頭列。每位團員固定佔 1 列；含換行的內容（護照、地址、備註）由欄位類型決定怎麼吃。")
                        .font(.caption2)
                }

                // ── 欄位對應 ──
                Section {
                    ForEach(0..<maxColumns, id: \.self) { colIdx in
                        columnMappingRow(colIdx: colIdx)
                            .listRowBackground(Color("AppCard"))
                    }
                } header: {
                    sectionHeader(icon: "arrow.left.arrow.right", title: "欄位對應")
                } footer: {
                    Text("選擇每一欄對應到的資料欄位，不需要的選「略過」。多行 cell 用「護照（號碼+發照+效期）」或「備註」吃整塊。")
                        .font(.caption2)
                }

                // ── 解析預覽 ──
                if !previewMembers.isEmpty {
                    Section {
                        ForEach(previewMembers.prefix(3)) { member in
                            previewMemberRow(member)
                                .listRowBackground(Color("AppCard"))
                        }
                        if previewMembers.count > 3 {
                            Text("⋯ 共 \(previewMembers.count) 人")
                                .font(.caption)
                                .foregroundStyle(Color(.systemGray))
                                .listRowBackground(Color("AppCard"))
                        }
                    } header: {
                        sectionHeader(icon: "eye", title: "解析預覽")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("欄位對應")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("開始解析") {
                    let config = buildConfig()
                    let members = TourMemberMapper.map(table: table, config: config)
                    onMapped(members)
                }
                .fontWeight(.semibold)
                .foregroundStyle(previewMembers.isEmpty ? Color(.systemGray) : Color("AppAccent"))
                .disabled(previewMembers.isEmpty)
            }
        }
        .onAppear { autoDetect() }
    }

    // MARK: - 原始表格視圖（支援多行 cell）

    private var rawTableView: some View {
        let displayRows = table.rows
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text("列")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(.systemGray))
                    .frame(width: 30, alignment: .center)

                ForEach(0..<maxColumns, id: \.self) { col in
                    Text("欄\(col + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: columnWidth(col), alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 4)
            .background(Color(.systemGray6))

            Divider()

            ForEach(Array(displayRows.enumerated()), id: \.offset) { rowIdx, row in
                let displayedRowNum = rowIdx + 1
                let isDataRow = displayedRowNum >= dataStartRow && displayedRowNum <= dataEndRow
                HStack(alignment: .top, spacing: 0) {
                    Text("\(displayedRowNum)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 30, alignment: .center)
                        .padding(.top, 6)

                    ForEach(0..<maxColumns, id: \.self) { col in
                        let cellValue = col < row.count ? row[col] : ""
                        Text(cellValue.isEmpty ? "—" : cellValue)
                            .font(.system(size: 11))
                            .foregroundStyle(cellValue.isEmpty ? Color(.systemGray4) : .primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: columnWidth(col), alignment: .topLeading)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 6)
                    }
                }
                .background(
                    isDataRow
                    ? Color(hex: "A06CD5").opacity(0.10)
                    : (rowIdx % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
                )
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    private func columnWidth(_ col: Int) -> CGFloat {
        // 取每行的最長 \n-split 子行決定欄寬
        let sample = table.rows.prefix(8).compactMap { row -> String? in
            col < row.count ? row[col] : nil
        }
        let maxLen = sample.flatMap { $0.split(separator: "\n") }
            .map { $0.count }.max() ?? 0
        return max(60, min(200, CGFloat(maxLen) * 7 + 16))
    }

    // MARK: - 欄位對應 Row

    private func columnMappingRow(colIdx: Int) -> some View {
        let sampleValue = sampleValue(colIdx: colIdx)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("欄 \(colIdx + 1)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color(.systemGray))
                if !sampleValue.isEmpty {
                    Text(sampleValue.replacingOccurrences(of: "\n", with: " ⏎ "))
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray2))
                        .lineLimit(2)
                }
            }
            .frame(width: 140, alignment: .leading)

            Spacer()

            Picker("", selection: Binding(
                get: {
                    columnMappings.first(where: { $0.columnIndex == colIdx })?.fieldType ?? .skip
                },
                set: { newValue in
                    if let i = columnMappings.firstIndex(where: { $0.columnIndex == colIdx }) {
                        columnMappings[i].fieldType = newValue
                    } else {
                        columnMappings.append(ColumnMapping(rowOffset: 0, columnIndex: colIdx, fieldType: newValue))
                    }
                    updatePreview()
                }
            )) {
                ForEach(MemberFieldType.allCases) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .pickerStyle(.menu)
            .tint(Color("AppAccent"))
        }
        .padding(.vertical, 2)
    }

    private func previewMemberRow(_ member: ParsedMember) -> some View {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd"

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let zh = member.nameZH {
                    Text(zh).fontWeight(.semibold)
                    Text(member.nameEN)
                        .foregroundStyle(Color(.systemGray))
                        .font(.caption)
                } else {
                    Text(member.nameEN).fontWeight(.semibold)
                }
                if let g = member.gender {
                    Text(g)
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(g == "M" ? Color.blue.opacity(0.1) : Color.pink.opacity(0.1))
                        .foregroundStyle(g == "M" ? Color.blue : Color.pink)
                        .clipShape(Capsule())
                }
            }
            HStack(spacing: 8) {
                if let no = member.passportNumber {
                    Text(no).font(.caption).foregroundStyle(Color(.systemGray))
                }
                if let expiry = member.passportExpiry {
                    Text("效期 \(df.string(from: expiry))").font(.caption).foregroundStyle(Color(.systemGray))
                }
                if let bday = member.birthday {
                    Text(df.string(from: bday)).font(.caption).foregroundStyle(Color(.systemGray))
                }
            }
            if let remark = member.remark, !remark.isEmpty {
                Text(remark)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "E8650A"))
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Color("AppAccent"))
            Text(title)
                .font(.footnote).fontWeight(.semibold)
                .foregroundStyle(Color(.systemGray))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func sampleValue(colIdx: Int) -> String {
        let sampleRowIdx = dataStartRow - 1
        guard sampleRowIdx < table.rows.count else { return "" }
        let row = table.rows[sampleRowIdx]
        guard colIdx < row.count else { return "" }
        return row[colIdx]
    }

    private func buildConfig() -> MappingConfig {
        MappingConfig(
            dataStartRow: dataStartRow,
            dataEndRow: dataEndRow,
            rowsPerMember: 1,
            columnMappings: columnMappings
        )
    }

    private func updatePreview() {
        previewMembers = TourMemberMapper.map(table: table, config: buildConfig())
    }

    // MARK: - 自動偵測

    private func autoDetect() {
        let rows = table.rows
        guard !rows.isEmpty else { return }

        // 表頭判定：看每個 cell 的「第一行」是不是短的 label 字串。
        // ≥ 2 個 cell 看起來像 label，整列視為表頭，跳過。
        // 純資料列（人名、護照號、日期、地址）第一行通常 > 8 字，不會被誤判。
        var startIdx = 0
        for (i, row) in rows.enumerated() {
            let nonEmpty = row.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
            if nonEmpty >= 2 && !looksLikeHeaderRow(row) {
                startIdx = i
                break
            }
        }

        dataStartRow = startIdx + 1
        dataEndRow = rows.count

        // 建欄位對應：每欄取多筆資料 sample，由內容判斷類型
        var mappings: [ColumnMapping] = []
        for colIdx in 0..<maxColumns {
            let samples = collectSamples(colIdx: colIdx, startIdx: startIdx)
            let field = detectField(samples: samples, colIdx: colIdx, totalCols: maxColumns)
            mappings.append(ColumnMapping(rowOffset: 0, columnIndex: colIdx, fieldType: field))
        }
        columnMappings = mappings
        updatePreview()
    }

    // 判斷一列是否為表頭：≥ 2 個 cell 的第一行看起來像 label
    private func looksLikeHeaderRow(_ row: [String]) -> Bool {
        // 常見表頭 label（中英文）。OCR 雜訊容忍：用「部分字元」吃，例如「護照」吃得到「護照號碼」「護照效期」「護照紋期日」。
        let labelFragments = [
            "序號", "編號", "姓名", "中文", "英文", "性別",
            "生日", "出生", "護照", "效期", "發照", "簽證",
            "身分", "證字", "證號", "地址", "電話", "手機",
            "備註", "需求", "禁忌", "房號",
            "name", "passport", "expir", "issue", "address",
            "phone", "gender", "birth", "remark", "note", "no.", "id"
        ]
        var headerCells = 0
        for cell in row {
            let firstLine = (cell.split(separator: "\n").first.map(String.init) ?? cell)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // label 通常很短；長字串（人名、護照號、日期、地址）跳過
            guard !firstLine.isEmpty, firstLine.count <= 8 else { continue }
            let lower = firstLine.lowercased()
            if labelFragments.contains(where: { lower.contains($0.lowercased()) || firstLine.contains($0) }) {
                headerCells += 1
            }
        }
        return headerCells >= 2
    }

    private func collectSamples(colIdx: Int, startIdx: Int) -> [String] {
        var samples: [String] = []
        for i in startIdx..<min(startIdx + 6, table.rows.count) {
            let row = table.rows[i]
            if colIdx < row.count {
                let v = row[colIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if !v.isEmpty { samples.append(v) }
            }
        }
        return samples
    }

    private func detectField(samples: [String], colIdx: Int, totalCols: Int) -> MemberFieldType {
        guard !samples.isEmpty else { return .skip }

        let datePattern  = try? NSRegularExpression(pattern: #"^\d{4}[/\-\.]\d{1,2}[/\-\.]\d{1,2}$"#)
        let datePatternAny = try? NSRegularExpression(pattern: #"\d{4}[/\-\.]\d{1,2}[/\-\.]\d{1,2}"#)
        let passportLinePattern = try? NSRegularExpression(pattern: #"^[A-Z]{0,2}\d{6,10}$"#)
        let idLinePattern = try? NSRegularExpression(pattern: #"^[A-Z]\d{9}$"#)

        var singleDate = 0
        var passportFull = 0
        var passportSingle = 0
        var idSingle = 0
        var nameENZH = 0
        var nameENOnly = 0
        var nameZHOnly = 0
        var multilineRemark = 0
        var seqNumber = 0

        let isUpperEN: (String) -> Bool = { line in
            line.unicodeScalars.allSatisfy {
                ($0.value >= 0x41 && $0.value <= 0x5A) || // A-Z
                $0 == " " || $0 == "," || $0 == "." || $0 == "-"
            } && line.contains(where: { $0.isLetter })
        }
        let isCJK: (String) -> Bool = { line in
            line.unicodeScalars.allSatisfy {
                ($0.value >= 0x4E00 && $0.value <= 0x9FFF) || $0 == " "
            } && line.contains(where: { ($0.unicodeScalars.first?.value ?? 0) >= 0x4E00 })
        }

        for s in samples {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            let lineCount = lines.count
            let firstLine = lines.first ?? ""
            let nsRange1 = NSRange(firstLine.startIndex..., in: firstLine)

            let dateLines = lines.filter {
                guard let p = datePatternAny else { return false }
                return p.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil
            }.count

            let upperENLines = lines.filter(isUpperEN).count
            let cjkLines = lines.filter(isCJK).count

            if lineCount == 1, let p = datePattern, p.firstMatch(in: firstLine, range: nsRange1) != nil {
                singleDate += 1
            }
            if lineCount == 1, let p = idLinePattern, p.firstMatch(in: firstLine, range: nsRange1) != nil {
                idSingle += 1
            }
            if lineCount == 1, let p = passportLinePattern, p.firstMatch(in: firstLine, range: nsRange1) != nil {
                passportSingle += 1
            }
            // 護照三合一：第一行像護照號 + 同 cell 內含日期
            if lineCount >= 2, dateLines >= 1,
               let p = passportLinePattern, p.firstMatch(in: firstLine, range: nsRange1) != nil {
                passportFull += 1
            }
            // 英中合一：上下兩行，一行全大寫 EN、一行 CJK
            if upperENLines >= 1 && cjkLines >= 1 { nameENZH += 1 }
            else if lineCount == 1 && isUpperEN(firstLine) { nameENOnly += 1 }
            else if lineCount == 1 && isCJK(firstLine) { nameZHOnly += 1 }

            // 多行文字、含 CJK、無日期、不像護照 → 視為 remark/地址
            if lineCount >= 2 && cjkLines >= 1 && dateLines == 0 && passportFull == 0 {
                multilineRemark += 1
            }
            // 序號（純數字 1~3 碼）
            if lineCount == 1, Int(firstLine) != nil, firstLine.count <= 3 {
                seqNumber += 1
            }
        }

        let n = samples.count
        let majority = n / 2 + 1

        if passportFull >= majority { return .passportFull }
        if singleDate >= majority { return .birthday }
        if nameENZH >= majority { return .nameENZH }
        if passportSingle >= majority { return .passportNo }
        if idSingle >= majority { return .nationalID }          // 身分證可推性別
        if nameENOnly >= majority { return .nameEN }
        if nameZHOnly >= majority { return .nameZH }
        if multilineRemark >= majority { return .remarkEssential }  // 預設只留必要資訊
        if seqNumber >= majority { return .skip }

        // 最後一欄通常是備註，預設只留必要資訊
        if colIdx == totalCols - 1 { return .remarkEssential }
        return .skip
    }
}
