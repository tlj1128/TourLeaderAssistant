import SwiftUI

struct TourMemberRawPreviewView: View {
    let team: Team
    let tables: [RawTable]
    let onMapped: ([ParsedMember]) -> Void

    // 選擇哪個表格
    @State private var selectedTableIndex: Int = 0

    // 解析設定
    @State private var dataStartRow: Int = 1
    @State private var dataEndRow: Int = 1
    @State private var rowsPerMember: Int = 1
    @State private var columnMappings: [ColumnMapping] = []

    // 預覽
    @State private var previewMembers: [ParsedMember] = []

    var selectedTable: RawTable {
        guard selectedTableIndex < tables.count else { return RawTable(rows: []) }
        return tables[selectedTableIndex].normalized()
    }

    var maxColumns: Int { selectedTable.maxColumnCount }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                // ── 多表格選擇（docx 可能有多個表格）──
                if tables.count > 1 {
                    Section {
                        Picker("選擇表格", selection: $selectedTableIndex) {
                            ForEach(0..<tables.count, id: \.self) { i in
                                Text("表格 \(i + 1)（\(tables[i].rowCount) 列）").tag(i)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                        .onChange(of: selectedTableIndex) { _, _ in
                            resetConfig()
                        }
                    } header: {
                        sectionHeader(icon: "tablecells", title: "選擇表格")
                    }
                }

                // ── 原始資料預覽 ──
                Section {
                    ScrollView(.horizontal, showsIndicators: true) {
                        rawTableView
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Color("AppCard"))
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                } header: {
                    sectionHeader(icon: "doc.text", title: "原始資料（共 \(selectedTable.rowCount) 列）")
                }

                // ── 資料範圍 ──
                Section {
                    Stepper("從第 \(dataStartRow) 列開始",
                            value: $dataStartRow,
                            in: 1...max(1, selectedTable.rowCount))
                    .listRowBackground(Color("AppCard"))
                    .onChange(of: dataStartRow) { _, _ in updatePreview() }

                    Stepper("到第 \(dataEndRow) 列結束",
                            value: $dataEndRow,
                            in: dataStartRow...max(dataStartRow, selectedTable.rowCount))
                    .listRowBackground(Color("AppCard"))
                    .onChange(of: dataEndRow) { _, _ in updatePreview() }

                    Stepper("每人佔 \(rowsPerMember) 列",
                            value: $rowsPerMember,
                            in: 1...5)
                    .listRowBackground(Color("AppCard"))
                    .onChange(of: rowsPerMember) { _, _ in
                        rebuildColumnMappings()
                        updatePreview()
                    }
                } header: {
                    sectionHeader(icon: "slider.horizontal.3", title: "資料範圍")
                }

                // ── 欄位對應 ──
                Section {
                    ForEach(0..<rowsPerMember, id: \.self) { rowOffset in
                        if rowsPerMember > 1 {
                            Text("第 \(rowOffset + 1) 列")
                                .font(.caption)
                                .foregroundStyle(Color(.systemGray))
                                .listRowBackground(Color("AppCard"))
                        }
                        ForEach(0..<maxColumns, id: \.self) { colIdx in
                            columnMappingRow(rowOffset: rowOffset, colIdx: colIdx)
                                .listRowBackground(Color("AppCard"))
                        }
                    }
                } header: {
                    sectionHeader(icon: "arrow.left.arrow.right", title: "欄位對應")
                } footer: {
                    Text("選擇每一欄對應到的資料欄位，不需要的選「略過」")
                        .font(.caption2)
                }

                // ── 解析預覽 ──
                if !previewMembers.isEmpty {
                    Section {
                        ForEach(previewMembers.prefix(3)) { member in
                            previewMemberRow(member)
                                .listRowBackground(Color("AppCard"))
                        }
                    } header: {
                        sectionHeader(icon: "eye", title: "解析預覽（前 3 筆）")
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
                    let members = TourMemberMapper.map(table: selectedTable, config: config)
                    onMapped(members)
                }
                .fontWeight(.semibold)
                .foregroundStyle(previewMembers.isEmpty ? Color(.systemGray) : Color("AppAccent"))
                .disabled(previewMembers.isEmpty)
            }
        }
        .onAppear {
            resetConfig()
        }
    }

    // MARK: - 原始表格視圖

    private var rawTableView: some View {
        let displayRows = selectedTable.rows

        return VStack(alignment: .leading, spacing: 0) {
            // 欄號標頭
            HStack(spacing: 0) {
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

            // 資料列
            ForEach(Array(displayRows.enumerated()), id: \.offset) { rowIdx, row in
                let isDataRow = (rowIdx + 1) >= dataStartRow && (rowIdx + 1) <= dataEndRow
                HStack(spacing: 0) {
                    // 列號
                    Text("\(rowIdx + 1)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 30, alignment: .center)

                    // 各欄內容
                    ForEach(0..<maxColumns, id: \.self) { col in
                        let cellValue = col < row.count ? row[col] : ""
                        Text(cellValue.isEmpty ? "—" : cellValue)
                            .font(.system(size: 11))
                            .foregroundStyle(cellValue.isEmpty ? Color(.systemGray4) : .primary)
                            .lineLimit(1)
                            .frame(width: columnWidth(col), alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 5)
                .background(
                    isDataRow
                    ? Color(hex: "A06CD5").opacity(0.08)
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

    // 動態計算欄寬
    private func columnWidth(_ col: Int) -> CGFloat {
        let sample = selectedTable.rows.prefix(5).compactMap { row -> String? in
            col < row.count ? row[col] : nil
        }
        let maxLen = sample.map { $0.count }.max() ?? 0
        return max(60, min(150, CGFloat(maxLen) * 7 + 16))
    }

    // MARK: - 欄位對應 Row

    private func columnMappingRow(rowOffset: Int, colIdx: Int) -> some View {
        let bindingIndex = mappingIndex(rowOffset: rowOffset, colIdx: colIdx)
        let sampleValue = sampleValue(rowOffset: rowOffset, colIdx: colIdx)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("欄 \(colIdx + 1)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Color(.systemGray))
                if !sampleValue.isEmpty {
                    Text(sampleValue)
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray2))
                        .lineLimit(1)
                }
            }
            .frame(width: 120, alignment: .leading)

            Spacer()

            Picker("", selection: Binding(
                get: {
                    bindingIndex < columnMappings.count
                    ? columnMappings[bindingIndex].fieldType
                    : .skip
                },
                set: { newValue in
                    if bindingIndex < columnMappings.count {
                        columnMappings[bindingIndex].fieldType = newValue
                        updatePreview()
                    }
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

    // MARK: - 解析預覽 Row

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
                Text(remark).font(.caption).foregroundStyle(Color(hex: "E8650A")).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - 輔助

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

    private func mappingIndex(rowOffset: Int, colIdx: Int) -> Int {
        rowOffset * maxColumns + colIdx
    }

    private func sampleValue(rowOffset: Int, colIdx: Int) -> String {
        let sampleRowIdx = dataStartRow - 1 + rowOffset
        guard sampleRowIdx < selectedTable.rows.count else { return "" }
        let row = selectedTable.rows[sampleRowIdx]
        guard colIdx < row.count else { return "" }
        return row[colIdx]
    }

    private func buildConfig() -> MappingConfig {
        MappingConfig(
            dataStartRow: dataStartRow,
            dataEndRow: dataEndRow,
            rowsPerMember: rowsPerMember,
            columnMappings: columnMappings
        )
    }

    private func resetConfig() {
        let table = selectedTable
        let config = TourMemberMapper.autoDetect(table: table)
        dataStartRow = config.dataStartRow
        dataEndRow = min(config.dataEndRow, table.rowCount)
        rowsPerMember = config.rowsPerMember
        columnMappings = config.columnMappings

        // 確保 columnMappings 有足夠的項目（每列每欄都有）
        rebuildColumnMappings(preserveExisting: true)
        updatePreview()
    }

    private func rebuildColumnMappings(preserveExisting: Bool = false) {
        var newMappings: [ColumnMapping] = []
        for rowOffset in 0..<rowsPerMember {
            for colIdx in 0..<maxColumns {
                let existing = preserveExisting
                ? columnMappings.first(where: { $0.rowOffset == rowOffset && $0.columnIndex == colIdx })
                : nil
                newMappings.append(
                    existing ?? ColumnMapping(rowOffset: rowOffset, columnIndex: colIdx, fieldType: .skip)
                )
            }
        }
        columnMappings = newMappings
    }

    private func updatePreview() {
        let config = buildConfig()
        previewMembers = TourMemberMapper.map(table: selectedTable, config: config)
    }
}
