import Foundation

// MARK: - 欄位類型

enum MemberFieldType: String, CaseIterable, Identifiable {
    // 預設 / 略過
    case skip        = "skip"

    // 姓名
    case nameEN      = "nameEN"
    case nameZH      = "nameZH"
    case nameENZH    = "nameENZH"    // 英文+中文合一

    // 個資
    case gender      = "gender"
    case birthday    = "birthday"
    case nationalID  = "nationalID"  // 台灣身分證；首位數字 1=M 2=F
    case birthdayID  = "birthdayID"  // 生日+身分證合一

    // 護照
    case passportNo  = "passportNo"
    case passportExpiry = "passportExpiry"
    case issueExpiry = "issueExpiry" // 發照日+效期合一
    case passportFull = "passportFull" // 號碼+發照+效期單欄多行

    // 房 / 備註
    case roomLabel   = "roomLabel"
    case remarkEssential = "remarkEssential"  // 只留機位/房/餐/需求等必要資訊
    case remark      = "remark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skip:          return "略過"
        case .nameEN:        return "英文姓名"
        case .nameZH:        return "中文姓名"
        case .nameENZH:      return "英文+中文（合一）"
        case .gender:        return "性別"
        case .birthday:      return "生日"
        case .passportNo:    return "護照號碼"
        case .passportExpiry: return "護照效期"
        case .passportFull:  return "護照（號碼+發照+效期）"
        case .issueExpiry:   return "發照日+效期（合一）"
        case .birthdayID:    return "生日+身分證（合一）"
        case .roomLabel:     return "房號"
        case .nationalID:    return "身分證字號"
        case .remark:        return "備註（所有）"
        case .remarkEssential: return "備註（僅需求）"
        }
    }
}

// MARK: - 欄位對應設定

struct ColumnMapping {
    var rowOffset: Int       // 第幾列（0-based，每人佔多列時使用）
    var columnIndex: Int     // 第幾欄（0-based）
    var fieldType: MemberFieldType
}

// MARK: - 解析設定

struct MappingConfig {
    var dataStartRow: Int        // 資料從第幾列開始（1-based，對應使用者看到的列號）
    var dataEndRow: Int          // 資料到第幾列結束（1-based）
    var rowsPerMember: Int       // 每人佔幾列
    var columnMappings: [ColumnMapping]  // 欄位對應

    // 每人每列的對應（依 rowOffset 分組）
    func mappingsForRow(_ rowOffset: Int) -> [ColumnMapping] {
        columnMappings.filter { $0.rowOffset == rowOffset }
    }
}

// MARK: - TourMemberMapper

struct TourMemberMapper {

    /// 自動偵測欄位對應（根據表頭關鍵字）
    static func autoDetect(table: RawTable) -> MappingConfig {
        let rows = table.normalized().rows
        guard !rows.isEmpty else {
            return MappingConfig(dataStartRow: 1, dataEndRow: 1,
                                 rowsPerMember: 1, columnMappings: [])
        }

        // 找表頭列：含有常見欄位關鍵字的列
        var headerRowIndex = 0
        var secondHeaderRowIndex: Int? = nil

        for (i, row) in rows.enumerated() {
            let joined = row.joined(separator: " ").lowercased()
            if joined.contains("name") || joined.contains("姓名") ||
               joined.contains("passport") || joined.contains("護照") ||
               joined.contains("english") || joined.contains("room") {
                headerRowIndex = i
                // 檢查下一列是否也是表頭（兩列表頭的情況）
                if i + 1 < rows.count {
                    let nextJoined = rows[i + 1].joined(separator: " ").lowercased()
                    if nextJoined.contains("chinese") || nextJoined.contains("birth") ||
                       nextJoined.contains("expir") || nextJoined.contains("效期") {
                        secondHeaderRowIndex = i + 1
                    }
                }
                break
            }
        }

        // 資料起始列（表頭後一列，或兩列表頭後）
        let dataStart = (secondHeaderRowIndex ?? headerRowIndex) + 2  // 1-based

        // 偵測每人幾列（看資料列的規律）
        let rowsPerMember = detectRowsPerMember(rows: rows, startIndex: dataStart - 1)

        // 建立欄位對應
        var mappings: [ColumnMapping] = []

        // 第一列表頭對應
        let headerRow = rows[headerRowIndex]
        for (colIdx, header) in headerRow.enumerated() {
            let field = detectField(from: header, isSecondRow: false)
            if field != .skip {
                mappings.append(ColumnMapping(rowOffset: 0, columnIndex: colIdx, fieldType: field))
            }
        }

        // 第二列表頭對應（如果有）
        if let secondIdx = secondHeaderRowIndex {
            let secondRow = rows[secondIdx]
            for (colIdx, header) in secondRow.enumerated() {
                let field = detectField(from: header, isSecondRow: true)
                if field != .skip {
                    mappings.append(ColumnMapping(rowOffset: 1, columnIndex: colIdx, fieldType: field))
                }
            }
        }

        return MappingConfig(
            dataStartRow: dataStart,
            dataEndRow: rows.count,
            rowsPerMember: rowsPerMember,
            columnMappings: mappings
        )
    }

    /// 按 MappingConfig 把 RawTable 轉成 [ParsedMember]
    static func map(table: RawTable, config: MappingConfig) -> [ParsedMember] {
        let rows = table.normalized().rows
        let startIdx = config.dataStartRow - 1  // 轉 0-based
        let endIdx = min(config.dataEndRow - 1, rows.count - 1)

        guard startIdx <= endIdx else { return [] }

        var members: [ParsedMember] = []
        var sortOrder = 0
        var i = startIdx

        while i <= endIdx {
            // 收集這個人的所有列
            var memberRows: [[String]] = []
            for offset in 0..<config.rowsPerMember {
                let rowIdx = i + offset
                if rowIdx <= endIdx {
                    memberRows.append(rows[rowIdx])
                } else {
                    memberRows.append([])
                }
            }

            if let member = buildMember(from: memberRows, config: config, sortOrder: sortOrder) {
                members.append(member)
                sortOrder += 1
            }

            i += config.rowsPerMember
        }

        // ── 房號後處理 ──
        let hasRoomColumn = config.columnMappings.contains { $0.fieldType == .roomLabel }

        if hasRoomColumn {
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
            // 沒有指定房號欄位：預設兩兩一間（01/01/02/02/03/03…）
            for i in members.indices {
                let roomNumber = i / 2 + 1
                members[i].roomLabel = String(format: "%02d", roomNumber)
            }
        }

        return members
    }

    // MARK: - 建立單筆 ParsedMember

    private static func buildMember(from memberRows: [[String]],
                                    config: MappingConfig,
                                    sortOrder: Int) -> ParsedMember? {
        var nameEN: String? = nil
        var nameZH: String? = nil
        var gender: String? = nil
        var birthday: Date? = nil
        var passportNumber: String? = nil
        var passportExpiry: Date? = nil
        var roomLabel: String? = nil
        var remarkParts: [String] = []

        for mapping in config.columnMappings {
            guard mapping.rowOffset < memberRows.count else { continue }
            let row = memberRows[mapping.rowOffset]
            guard mapping.columnIndex < row.count else { continue }
            let value = row[mapping.columnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }

            switch mapping.fieldType {
            case .skip:
                break

            case .nameEN:
                nameEN = value

            case .nameZH:
                nameZH = cleanChineseName(value)

            case .nameENZH:
                // 英中合一：找第一個中文字分割
                let (en, zh, g) = splitNameCell(value)
                if nameEN == nil { nameEN = en }
                if nameZH == nil { nameZH = zh }
                if gender == nil { gender = g }

            case .gender:
                gender = normalizeGender(value)

            case .birthday:
                birthday = parseDate(value)

            case .passportNo:
                passportNumber = extractPassportNumber(value) ?? value

            case .passportExpiry:
                // 多行 cell 也支援：抓出最大的日期當效期
                let dates = extractAllDates(from: value)
                passportExpiry = dates.max() ?? parseDate(value)

            case .passportFull:
                // 號碼 + 發照日 + 效期 三合一單欄
                passportNumber = extractPassportNumber(value)
                let dates = extractAllDates(from: value)
                if let maxD = dates.max() { passportExpiry = maxD }

            case .issueExpiry:
                // 發照日+效期合一：取較晚的日期
                passportExpiry = extractAllDates(from: value).max()

            case .birthdayID:
                // 生日+身分證合一：取較早的日期
                birthday = extractAllDates(from: value).min()

            case .roomLabel:
                let digitsOnly = value.filter { $0.isNumber }
                if !digitsOnly.isEmpty { roomLabel = digitsOnly }

            case .nationalID:
                // 台灣身分證 [A-Z]\d{9}，首位數字 1=M、2=F
                // 只在沒有顯式性別欄時補；不覆蓋既有 gender
                if gender == nil {
                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                    if trimmed.count >= 2 {
                        let secondChar = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)]
                        if secondChar == "1" { gender = "M" }
                        else if secondChar == "2" { gender = "F" }
                    }
                }

            case .remark:
                remarkParts.append(value)

            case .remarkEssential:
                let lines = value.split(separator: "\n", omittingEmptySubsequences: true)
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                let kept = lines.filter { isEssentialRemarkLine($0) }
                if !kept.isEmpty {
                    remarkParts.append(kept.joined(separator: " "))
                }
            }
        }

        // 至少要有英文名或中文名
        guard nameEN != nil || nameZH != nil else { return nil }

        // 如果只有中文名，用中文名填英文名欄位
        if nameEN == nil { nameEN = nameZH ?? "" }

        return ParsedMember(
            nameEN: nameEN ?? "",
            nameZH: nameZH,
            gender: gender,
            birthday: birthday,
            passportNumber: passportNumber,
            passportExpiry: passportExpiry,
            roomLabel: roomLabel,
            remark: remarkParts.isEmpty ? nil : remarkParts.joined(separator: " "),
            sortOrder: sortOrder
        )
    }

    // MARK: - 自動偵測每人幾列

    private static func detectRowsPerMember(rows: [[String]], startIndex: Int) -> Int {
        guard startIndex < rows.count else { return 1 }

        // 看第一列和第二列的第一欄是否都有值
        // 如果第二列第一欄是空的，很可能是兩列一人
        if startIndex + 1 < rows.count {
            let firstRowFirstCol = rows[startIndex].first ?? ""
            let secondRowFirstCol = rows[startIndex + 1].first ?? ""

            if !firstRowFirstCol.isEmpty && secondRowFirstCol.isEmpty {
                return 2
            }
        }

        return 1
    }

    // MARK: - 欄位關鍵字偵測

    private static func detectField(from header: String, isSecondRow: Bool) -> MemberFieldType {
        let lower = header.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if lower.isEmpty { return .skip }

        // 合一欄位（優先偵測）
        if lower.contains("english") && lower.contains("chinese") { return .nameENZH }
        if lower.contains("issue") && lower.contains("expir") { return .issueExpiry }
        if lower.contains("birth") && (lower.contains("id") || lower.contains("身分")) { return .birthdayID }
        if lower.contains("護照號") && lower.contains("發照") { return .issueExpiry }

        // 單一欄位
        if lower.contains("english") || lower == "name" { return .nameEN }
        if lower.contains("chinese") || lower.contains("中文") { return .nameZH }
        if lower.contains("title") || lower.contains("gender") ||
           lower == "m" || lower == "f" || lower == "m/f" { return .gender }
        if lower.contains("birth") || lower.contains("生日") { return .birthday }
        if lower.contains("passport") && (lower.contains("no") || lower.contains("號")) { return .passportNo }
        if lower.contains("expir") || lower.contains("效期") { return .passportExpiry }
        if lower.contains("room") || lower.contains("房") { return .roomLabel }
        if lower.contains("remark") || lower.contains("備註") || lower.contains("note") { return .remark }
        if lower.contains("序號") || lower == "no" || lower == "no." { return .skip }
        if lower.contains("地址") || lower.contains("address") { return .skip }
        if lower.contains("電話") || lower.contains("phone") { return .skip }
        if lower.contains("身分證") || lower.contains("id") { return .skip }
        if lower.contains("issue") || lower.contains("發照") { return .skip }

        return .skip
    }

    // MARK: - 輔助函式

    static func splitNameCell(_ cell: String) -> (nameEN: String?, nameZH: String?, gender: String?) {
        var gender: String? = nil
        var remaining = cell

        for prefix in ["MR. ", "MRS. ", "MS. ", "MISS ", "MR ", "MRS ", "MS "] {
            if remaining.uppercased().hasPrefix(prefix) {
                let up = prefix.uppercased()
                gender = (up.hasPrefix("MR") && !up.hasPrefix("MRS")) ? "M" : "F"
                remaining = String(remaining.dropFirst(prefix.count))
                break
            }
        }

        var chineseStartOffset = remaining.unicodeScalars.count
        for (offset, scalar) in remaining.unicodeScalars.enumerated() {
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                chineseStartOffset = offset
                break
            }
        }

        let chineseStart = remaining.unicodeScalars.index(
            remaining.unicodeScalars.startIndex,
            offsetBy: chineseStartOffset
        )

        let nameEN = String(remaining.unicodeScalars[..<chineseStart])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let nameZH = String(remaining.unicodeScalars[chineseStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")

        return (nameEN.isEmpty ? nil : nameEN,
                nameZH.isEmpty ? nil : nameZH,
                gender)
    }

    static func extractAllDates(from s: String) -> [Date] {
        let pattern = #"\d{4}[/\-]\d{2}[/\-]\d{2}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: s) else { return nil }
            return parseDate(String(s[range]))
        }
    }

    static func extractPassportNumber(_ s: String) -> String? {
        let pattern = #"[A-Za-z]{0,2}\d{6,9}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(match.range, in: s) else { return nil }
        return String(s[range])
    }

    /// 判斷一行備註是否為「必要資訊」（機位 / 房 / 餐 / 飲食需求等）
    /// 用來支援 .remarkEssential，把地址、電話這類沒實用的內容濾掉
    static func isEssentialRemarkLine(_ line: String) -> Bool {
        let l = line.lowercased()
        let keywords = [
            // 機位
            "機位", "靠窗", "走道", "鄰座", "前排", "後排", "選位",
            // 房型
            "房", "同房", "不同房", "床", "single", "double", "twin",
            // 餐 / 飲食
            "餐", "食", "不吃", "素", "葷", "過敏", "忌口", "忌",
            "vegetarian", "vegan", "kosher", "halal",
            // 其他需求
            "需求", "特殊", "輪椅", "嬰兒", "兒童餐", "兒童",
            "升等", "蜜月", "慶生", "wheelchair"
        ]
        return keywords.contains { l.contains($0) }
    }

    static func cleanChineseName(_ s: String) -> String? {
        let cleaned = s
            .components(separatedBy: CharacterSet(charactersIn: "（("))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{3000} "))
        return (cleaned?.isEmpty ?? true) ? nil : cleaned
    }

    static func normalizeGender(_ s: String?) -> String? {
        guard let s = s else { return nil }
        let upper = s.uppercased().trimmingCharacters(in: .whitespaces)
        if ["M", "MALE", "MR", "MR."].contains(upper) { return "M" }
        if ["F", "FEMALE", "MRS", "MS", "MISS", "MRS.", "MS."].contains(upper) { return "F" }
        return nil
    }

    private static let dateParsers: [DateFormatter] = {
        ["yyyy/MM/dd", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "yyyyMMdd", "dd.MM.yyyy"].map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }
    }()

    static func parseDate(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return dateParsers.lazy.compactMap { $0.date(from: trimmed) }.first
    }
}
