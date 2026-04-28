import SwiftUI

// MARK: - OCR 欄位設定

struct OCRFieldConfig: Identifiable {
    let id = UUID()
    let fieldType: MemberFieldType
    var startRow: Int    // 起始列（1-based，0 = 不抓）
    var gap: Int         // 間隔列數（0 = 連續，1 = 隔一列...）
}

// MARK: - TourMemberOCRMappingView

struct TourMemberOCRMappingView: View {
    let team: Team
    let ocrLines: [String]
    let onMapped: ([ParsedMember]) -> Void

    @State private var memberCount: Int = 1
    @State private var fieldConfigs: [OCRFieldConfig] = []
    @State private var previewMembers: [ParsedMember] = []

    private let editableFields: [MemberFieldType] = [
        .nameEN, .nameZH, .gender, .birthday,
        .passportNo, .passportExpiry, .roomLabel, .remark
    ]

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {

                // ── 1. 原始資料 ──
                Section {
                    rawDataBox
                        .listRowBackground(Color("AppCard"))
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    sectionHeader(icon: "doc.text",
                                  title: "原始資料（共 \(ocrLines.count) 列）")
                }

                // ── 2. 旅客人數 ──
                Section {
                    Stepper("旅客人數：\(memberCount)",
                            value: $memberCount, in: 1...200)
                        .listRowBackground(Color("AppCard"))
                        .onChange(of: memberCount) { _, _ in updatePreview() }
                } header: {
                    sectionHeader(icon: "person.2", title: "旅客人數")
                }

                // ── 3. 欄位對應 ──
                Section {
                    ForEach($fieldConfigs) { $config in
                        fieldConfigRow(config: $config)
                            .listRowBackground(Color("AppCard"))
                    }
                } header: {
                    sectionHeader(icon: "arrow.left.arrow.right", title: "欄位對應")
                } footer: {
                    Text("設定每個欄位的起始列號（對應左側列號）和間隔列數，起始列設 0 表示不抓取此欄位")
                        .font(.caption2)
                }

                // ── 4. 解析預覽 ──
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
        .navigationTitle("圖片欄位對應")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("開始解析") {
                    onMapped(buildAllMembers())
                }
                .fontWeight(.semibold)
                .foregroundStyle(previewMembers.isEmpty
                                 ? Color(.systemGray) : Color("AppAccent"))
                .disabled(previewMembers.isEmpty)
            }
        }
        .onAppear {
            initFieldConfigs()
            autoDetectMemberCount()
        }
    }

    // MARK: - 原始資料框（直式固定高度捲軸）

    private var rawDataBox: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ocrLines.enumerated()), id: \.offset) { idx, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(.systemGray))
                            .frame(width: 30, alignment: .trailing)
                        Text(line.isEmpty ? "—" : line)
                            .font(.system(size: 12))
                            .foregroundStyle(line.isEmpty ? Color(.systemGray4) : .primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(idx % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
                }
            }
        }
        .frame(maxHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    // MARK: - 欄位設定 Row（Stepper）

    private func fieldConfigRow(config: Binding<OCRFieldConfig>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(config.wrappedValue.fieldType.displayName)
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                // 起始列對應的預覽值
                if config.wrappedValue.startRow > 0,
                   config.wrappedValue.startRow <= ocrLines.count {
                    Text(ocrLines[config.wrappedValue.startRow - 1])
                        .font(.system(size: 11))
                        .foregroundStyle(Color("AppAccent"))
                        .lineLimit(1)
                        .frame(maxWidth: 120, alignment: .trailing)
                }
            }

            HStack(spacing: 16) {
                // 起始列：TextField 輸入
                HStack(spacing: 6) {
                    Text("起始列")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                    TextField("0", value: config.startRow, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .font(.system(size: 14, design: .monospaced))
                        .onChange(of: config.wrappedValue.startRow) { _, _ in updatePreview() }
                    Text(config.wrappedValue.startRow == 0 ? "不抓取" : "")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray3))
                }

                // 間隔：Stepper
                Stepper("間隔 \(config.wrappedValue.gap) 列",
                        value: config.gap, in: 0...20)
                    .onChange(of: config.wrappedValue.gap) { _, _ in updatePreview() }
            }
        }
        .padding(.vertical, 6)
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
                    Text("效期 \(df.string(from: expiry))")
                        .font(.caption).foregroundStyle(Color(.systemGray))
                }
                if let bday = member.birthday {
                    Text(df.string(from: bday))
                        .font(.caption).foregroundStyle(Color(.systemGray))
                }
            }
            if let room = member.roomLabel, !room.isEmpty {
                Label(room, systemImage: "bed.double")
                    .font(.caption).foregroundStyle(Color(.systemGray))
            }
            if let remark = member.remark, !remark.isEmpty {
                Text(remark).font(.caption)
                    .foregroundStyle(Color(hex: "E8650A")).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Section Header

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

    // MARK: - 初始化

    private func initFieldConfigs() {
        fieldConfigs = editableFields.map {
            OCRFieldConfig(fieldType: $0, startRow: 0, gap: 0)
        }
    }

    private func autoDetectMemberCount() {
        var count = 0
        for line in ocrLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if Int(trimmed) != nil {
                count += 1
            } else {
                break
            }
        }
        if count > 0 { memberCount = count }
    }

    // MARK: - 解析邏輯

    private func extractValues(config: OCRFieldConfig) -> [String] {
        guard config.startRow > 0 else { return [] }
        var values: [String] = []
        let step = 1 + config.gap
        for i in 0..<memberCount {
            let lineIdx = config.startRow - 1 + i * step
            if lineIdx < ocrLines.count {
                values.append(ocrLines[lineIdx].trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                values.append("")
            }
        }
        return values
    }

    private func buildAllMembers() -> [ParsedMember] {
        var fieldValues: [MemberFieldType: [String]] = [:]
        for config in fieldConfigs {
            fieldValues[config.fieldType] = extractValues(config: config)
        }

        var members: [ParsedMember] = []
        for i in 0..<memberCount {
            let nameEN = fieldValues[.nameEN]?[safe: i] ?? ""
            let nameZH = fieldValues[.nameZH]?[safe: i]
            let gender = TourMemberMapper.normalizeGender(fieldValues[.gender]?[safe: i])
            let birthday = TourMemberMapper.parseDate(fieldValues[.birthday]?[safe: i])
            let passportNo = fieldValues[.passportNo]?[safe: i]
            let passportExpiry = TourMemberMapper.parseDate(fieldValues[.passportExpiry]?[safe: i])
            let roomLabel = fieldValues[.roomLabel]?[safe: i]
            let remark = fieldValues[.remark]?[safe: i]

            let hasName = !nameEN.isEmpty || !(nameZH?.isEmpty ?? true)
            guard hasName else { continue }

            members.append(ParsedMember(
                nameEN: nameEN,
                nameZH: (nameZH?.isEmpty ?? true) ? nil : nameZH,
                gender: gender,
                birthday: birthday,
                passportNumber: (passportNo?.isEmpty ?? true) ? nil : passportNo,
                passportExpiry: passportExpiry,
                roomLabel: (roomLabel?.isEmpty ?? true) ? nil : roomLabel,
                remark: (remark?.isEmpty ?? true) ? nil : remark,
                sortOrder: i
            ))
        }

        // ── 房號後處理 ──
        let hasRoomConfig = fieldConfigs.contains { $0.fieldType == .roomLabel && $0.startRow > 0 }

        if hasRoomConfig {
            // 有指定房號欄位：空白的繼承前一筆
            var lastRoom: String? = nil
            for i in members.indices {
                if let room = members[i].roomLabel, !room.isEmpty {
                    lastRoom = room
                } else {
                    members[i].roomLabel = lastRoom
                }
            }
        } else {
            // 沒有指定房號：預設兩兩一間
            for i in members.indices {
                let roomNumber = i / 2 + 1
                members[i].roomLabel = String(format: "%02d", roomNumber)
            }
        }

        return members
    }

    private func updatePreview() {
        previewMembers = buildAllMembers()
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
