import Foundation

// MARK: - 資料結構

enum DietaryScope: Codable {
    case airborne
    case tripWide
}

struct DietaryNeed: Identifiable, Codable {
    let id = UUID()
    let category: DietaryCategory
    let label: String
    let scope: DietaryScope
    let sortKey: Int
    var isAIGenerated: Bool = false
}

enum DietaryCategory: String, CaseIterable, Codable {
    case allergy     = "過敏"
    case vegetarian  = "素食"
    case avoidFood   = "不吃特定食物"
    case airlineMeal = "機上特殊餐"

    var icon: String {
        switch self {
        case .allergy:     return "exclamationmark.triangle.fill"
        case .vegetarian:  return "leaf.fill"
        case .avoidFood:   return "xmark.circle.fill"
        case .airlineMeal: return "airplane"
        }
    }

    var sortOrder: Int {
        switch self {
        case .allergy:     return 0
        case .vegetarian:  return 1
        case .avoidFood:   return 2
        case .airlineMeal: return 3
        }
    }
}

// MARK: - 已知機上餐代碼

private let airlineCodes = ["VOML", "VGML", "VLML", "MOML", "KSML", "HNML",
                             "CHML", "BBML", "GFML", "DBML", "AVML", "FPML",
                             "SFML", "LFML", "LSML", "BLML", "NLML", "PFML"]

// MARK: - DietaryParser

struct DietaryParser {

    // MARK: - 主要入口

    static func parse(remark: String) async -> [DietaryNeed] {
        guard !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        var needs = parseWithRules(remark: remark)

        if #available(iOS 26, *) {
            let useAI = UserDefaults.standard.bool(forKey: "useLocalAI")
            if useAI && FoundationModelManager.shared.isAvailable {
                do {
                    needs = try await withThrowingTaskGroup(of: [DietaryNeed].self) { group in
                        group.addTask {
                            try await supplementWithAI(remark: remark, existing: needs)
                        }
                        group.addTask {
                            try await Task.sleep(for: .seconds(5))
                            throw CancellationError()
                        }
                        let result = try await group.next()!
                        group.cancelAll()
                        return result
                    }
                } catch {
                    // AI 超時或失敗，維持 rule-based 結果
                }
            }
        }

        return needs
    }

    // MARK: - Rule-based 主流程

    static func parseWithRules(remark: String) -> [DietaryNeed] {
        // Step 1：提取機上段，並從全文移除
        let (airborneNeeds, remaining) = extractAndRemoveAirborne(from: remark)

        // Step 2：對剩餘文字解析行程中需求
        let tripNeeds = extractTripWideNeeds(from: remaining)

        // Step 3：合併去重
        return deduplicate(airborneNeeds + tripNeeds)
    }

    // MARK: - Step 1：機上段提取與移除

    /// 找「機上」後面的片段，識別為機上餐，並從全文移除
    /// 規則：
    /// - 有已知代碼 → 截到代碼結束（含代碼前的素食名稱與緊鄰括號）
    /// - 沒有代碼 → 截到第一個「餐」字（含）
    private static func extractAndRemoveAirborne(from text: String) -> (needs: [DietaryNeed], remaining: String) {
        var needs: [DietaryNeed] = []
        var remaining = text
        var sortKey = 0

        // 反覆找「機上」，每次找到就處理並移除
        while let airborneRange = remaining.range(of: "機上") {
            // 取「機上」後面的文字
            let afterAirborne = String(remaining[airborneRange.upperBound...])

            // 找機上段結束位置
            let (airborneContent, contentLength) = findAirborneContent(in: afterAirborne)

            // 識別機上需求
            let airborneNeeds = identifyAirborneNeeds(from: airborneContent, sortKey: &sortKey)
            needs += airborneNeeds

            // 從 remaining 移除「機上」+ 機上段內容
            let removeEnd = remaining.index(airborneRange.lowerBound,
                                            offsetBy: "機上".count + contentLength,
                                            limitedBy: remaining.endIndex) ?? remaining.endIndex
            remaining = String(remaining[..<airborneRange.lowerBound])
                      + String(remaining[removeEnd...])
            remaining = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (needs, remaining)
    }

    /// 找機上段內容和長度
    /// 返回：(內容字串, 字元數)
    private static func findAirborneContent(in text: String) -> (String, Int) {
        // 優先：找已知代碼
        for code in airlineCodes {
            // 代碼可能在括號前面的文字裡，找到後截到代碼結束
            if let codeRange = text.range(of: code, options: .caseInsensitive) {
                // 包含代碼結束後緊鄰的括號內容
                var endIndex = codeRange.upperBound
                if endIndex < text.endIndex {
                    let afterCode = text[endIndex...]
                    if afterCode.hasPrefix("(") || afterCode.hasPrefix("（") {
                        if let closeIdx = findClosingParen(in: String(afterCode)) {
                            endIndex = text.index(endIndex, offsetBy: closeIdx,
                                                  limitedBy: text.endIndex) ?? endIndex
                        }
                    }
                }
                let content = String(text[..<endIndex])
                return (content, text.distance(from: text.startIndex, to: endIndex))
            }
        }

        // 次選：截到第一個「餐」字（含）
        if let mealIdx = text.firstIndex(of: "餐") {
            let endIndex = text.index(after: mealIdx)
            let content = String(text[..<endIndex])
            return (content, text.distance(from: text.startIndex, to: endIndex))
        }

        // fallback：取到第一個分隔符
        let stopChars = CharacterSet(charactersIn: "，,_\n")
        if let stopIdx = text.unicodeScalars.firstIndex(where: { stopChars.contains($0) }) {
            let strIdx = String.Index(stopIdx, within: text) ?? text.endIndex
            let content = String(text[..<strIdx])
            return (content, text.distance(from: text.startIndex, to: strIdx))
        }

        return (text, text.count)
    }

    /// 找字串中第一個括號的結束位置（字元數，含結束括號）
    private static func findClosingParen(in text: String) -> Int? {
        let open: Character = text.hasPrefix("(") ? "(" : "（"
        let close: Character = open == "(" ? ")" : "）"
        var depth = 0
        for (i, c) in text.enumerated() {
            if c == open { depth += 1 }
            if c == close {
                depth -= 1
                if depth == 0 { return i + 1 }
            }
        }
        return nil
    }

    /// 從機上段內容識別需求
    private static func identifyAirborneNeeds(from content: String, sortKey: inout Int) -> [DietaryNeed] {
        var needs: [DietaryNeed] = []
        let upper = content.uppercased()
        let lower = content.lowercased()

        func add(_ label: String) {
            needs.append(DietaryNeed(category: .airlineMeal, label: label,
                                     scope: .airborne, sortKey: sortKey))
            sortKey += 1
        }

        // 素食類（優先）
        if upper.contains("VOML") || lower.contains("東方素") || lower.contains("中式素") {
            add("VOML（東方素）")
        } else if upper.contains("VGML") || lower.contains("全素") || lower.contains("純素") {
            add("VGML（全素）")
        } else if upper.contains("VLML") || lower.contains("蛋奶素") || lower.contains("奶蛋素") {
            add("VLML（蛋奶素）")
        } else if upper.contains("AVML") || lower.contains("印度素食") {
            add("AVML（印度素食）")
        } else if lower.contains("素") {
            add("素食餐")
        }

        // 宗教餐
        if upper.contains("MOML") || lower.contains("清真") || lower.contains("穆斯林") {
            add("MOML（清真餐）")
        }
        if upper.contains("KSML") || lower.contains("猶太") {
            add("KSML（猶太潔食）")
        }
        if upper.contains("HNML") || lower.contains("印度教") {
            add("HNML（印度教餐）")
        }

        // 特殊餐
        if upper.contains("CHML") || lower.contains("兒童餐") || lower.contains("小孩餐") {
            add("CHML（兒童餐）")
        }
        if upper.contains("BBML") || lower.contains("嬰兒餐") {
            add("BBML（嬰兒餐）")
        }
        if upper.contains("GFML") {
            add("GFML（麩質過敏）")
        }
        if upper.contains("DBML") || lower.contains("糖尿病") {
            add("DBML（糖尿病餐）")
        }
        if upper.contains("PFML") {
            add("PFML（花生過敏）")
        }
        if upper.contains("BLML") {
            add("BLML（不吃辣）")
        }
        if upper.contains("NLML") {
            add("NLML（乳糖不耐）")
        }
        if upper.contains("LFML") {
            add("LFML（低脂餐）")
        }
        if upper.contains("LSML") {
            add("LSML（低鈉餐）")
        }
        if upper.contains("FPML") {
            add("FPML（水果餐）")
        }
        if upper.contains("SFML") {
            add("SFML（海鮮餐）")
        }

        // 不吃牛（機上）
        if lower.contains("不吃牛") || lower.contains("不食牛") ||
           (lower.contains("牛") && !lower.contains("素")) {
            add("不吃牛肉")
        }

        return needs
    }

    // MARK: - Step 2：行程中解析（只對剩餘文字，不解析代碼）

    private static func extractTripWideNeeds(from text: String) -> [DietaryNeed] {
        guard !text.isEmpty else { return [] }
        let lower = text.lowercased()
        var needs: [DietaryNeed] = []

        // ── 過敏（優先）──
        if lower.contains("甲殼") || lower.contains("蝦過敏") || lower.contains("蟹過敏") {
            needs.append(DietaryNeed(category: .allergy, label: "甲殼類過敏",
                                     scope: .tripWide, sortKey: 0))
        }
        if lower.contains("花生過敏") || lower.contains("花生 過敏") {
            needs.append(DietaryNeed(category: .allergy, label: "花生過敏",
                                     scope: .tripWide, sortKey: 1))
        }
        if lower.contains("海鮮過敏") {
            needs.append(DietaryNeed(category: .allergy, label: "海鮮過敏",
                                     scope: .tripWide, sortKey: 2))
        }
        if lower.contains("堅果過敏") {
            needs.append(DietaryNeed(category: .allergy, label: "堅果過敏",
                                     scope: .tripWide, sortKey: 3))
        }
        if lower.contains("麩質") || lower.contains("麵筋") {
            needs.append(DietaryNeed(category: .allergy, label: "麩質過敏",
                                     scope: .tripWide, sortKey: 4))
        }
        if lower.contains("乳糖不耐") || lower.contains("乳製品過敏") {
            needs.append(DietaryNeed(category: .allergy, label: "乳糖不耐",
                                     scope: .tripWide, sortKey: 5))
        }
        if lower.contains("蛋過敏") {
            needs.append(DietaryNeed(category: .allergy, label: "蛋過敏",
                                     scope: .tripWide, sortKey: 6))
        }

        // ── 素食 ──
        // 找素食關鍵字，連同緊鄰括號內容一起作為 label
        if let vegLabel = extractVegLabel(from: text) {
            needs.append(DietaryNeed(category: .vegetarian, label: vegLabel,
                                     scope: .tripWide, sortKey: 0))
        }

        // ── 不吃特定食物 ──
        let avoidItems = extractAvoidList(from: text)
        for (idx, item) in avoidItems.enumerated() {
            needs.append(DietaryNeed(category: .avoidFood, label: "不吃\(item)",
                                     scope: .tripWide, sortKey: idx))
        }
        if lower.contains("洋蔥") || lower.contains("青蔥") ||
           lower.contains("蔥蒜") || lower.contains("不吃蔥") {
            needs.append(DietaryNeed(category: .avoidFood, label: "不吃蔥蒜",
                                     scope: .tripWide, sortKey: 10))
        }
        if lower.contains("不吃生食") || lower.contains("生魚片") ||
           (lower.contains("不吃生") && !lower.contains("不吃生魚")) {
            needs.append(DietaryNeed(category: .avoidFood, label: "不吃生食",
                                     scope: .tripWide, sortKey: 11))
        }
        
        // ── 不吃辣 ──
        if lower.contains("不吃辣") || lower.contains("不辣") || lower.contains("怕辣") || lower.contains("避辣") {
            needs.append(DietaryNeed(category: .avoidFood, label: "不吃辣",
                                     scope: .tripWide, sortKey: 12))
        }

        // ── 糖尿病飲食 ──
        if lower.contains("糖尿病") || lower.contains("低糖") || lower.contains("控糖") {
            needs.append(DietaryNeed(category: .avoidFood, label: "糖尿病飲食",
                                     scope: .tripWide, sortKey: 13))
        }
        
        // ── 低鈉飲食 ──
        if lower.contains("低鈉") || lower.contains("少鹽") || lower.contains("不吃鹽") || lower.contains("限鈉") {
            needs.append(DietaryNeed(category: .avoidFood, label: "低鈉飲食",
                                     scope: .tripWide, sortKey: 14))
        }

        return needs
    }

    // MARK: - 素食 label 提取（含括號描述）

    private static func extractVegLabel(from text: String) -> String? {
        let lower = text.lowercased()

        // 素食關鍵字
        let vegKeywords = ["全素", "純素", "東方素", "中式素", "五辛素",
                           "蛋奶素", "奶蛋素", "蛋素", "奶素", "印度素食",
                           "素食", "吃素"]

        guard let keyword = vegKeywords.first(where: { lower.contains($0) }) else { return nil }

        // 找關鍵字在原文的位置（保留原始大小寫）
        guard let kwRange = text.range(of: keyword, options: .caseInsensitive) else {
            return "素食"
        }

        // 找關鍵字後面緊鄰的括號
        let endIndex = kwRange.upperBound
        if endIndex < text.endIndex {
            let afterKw = String(text[endIndex...])
            let trimmed = afterKw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("(") || trimmed.hasPrefix("（") {
                if let closeLen = findClosingParen(in: trimmed) {
                    let parenContent = String(trimmed.prefix(closeLen))
                    // 轉換括號為全形
                    let normalizedParen = parenContent
                        .replacingOccurrences(of: "(", with: "（")
                        .replacingOccurrences(of: ")", with: "）")
                    return "素食\(normalizedParen)"
                }
            }
        }

        // 特殊關鍵字對應
        if keyword == "印度素食" { return "素食（印度）" }
        if keyword == "吃素" { return "素食" }
        return "素食"
    }

    // MARK: - 枚舉型「不吃 X Y Z」

    private static func extractAvoidList(from text: String) -> [String] {
        let foodMap: [(pattern: String, label: String, sortKey: Int)] = [
            ("牛肉|不吃牛|不食牛|\\b牛\\b", "牛肉", 0),
            ("羊肉|不吃羊|不食羊|\\b羊\\b", "羊肉", 1),
            ("豬肉|不吃豬|不食豬|\\b豬\\b", "豬肉", 2),
            ("雞肉|不吃雞|不食雞|\\b雞\\b", "雞肉", 3),
            ("生魚片|不吃生魚|生魚",         "生魚", 5),  // 生魚優先於魚
            ("魚肉|不吃魚|不食魚|\\b魚\\b",  "魚",   4),
            ("海鮮|不吃海鮮|不食海鮮",        "海鮮", 6),
        ]

        var results: [String] = []
        var usedLabels: Set<String> = []

        // 抓「不[吃食]」後面的詞組
        let pattern = "不[吃食]\\s*([\\u4e00-\\u9fff\\s、，,]+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let chunk = String(text[range])
                for food in foodMap {
                    guard !usedLabels.contains(food.label) else { continue }
                    if let r = try? NSRegularExpression(pattern: food.pattern),
                       r.firstMatch(in: chunk, range: NSRange(chunk.startIndex..., in: chunk)) != nil {
                        results.append(food.label)
                        usedLabels.insert(food.label)
                    }
                }
            }
        }

        // 補漏：有「不吃/不食」上下文的單字
        for food in foodMap {
            guard !usedLabels.contains(food.label) else { continue }
            let ctx = "不[吃食][^。！？\\n]*\(food.pattern)"
            if let r = try? NSRegularExpression(pattern: ctx),
               r.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                results.append(food.label)
                usedLabels.insert(food.label)
            }
        }

        // 生魚優先，有生魚就移除魚
        var sorted = results.sorted { a, b in
            let ka = foodMap.first { $0.label == a }?.sortKey ?? 99
            let kb = foodMap.first { $0.label == b }?.sortKey ?? 99
            return ka < kb
        }
        if sorted.contains("生魚") { sorted.removeAll { $0 == "魚" } }
        return sorted
    }

    // MARK: - 去重

    private static func deduplicate(_ needs: [DietaryNeed]) -> [DietaryNeed] {
        
        var byKey: [String: DietaryNeed] = [:]
        for need in needs {
            let key = "\(need.label)|\(need.scope)"
            if byKey[key] == nil {
                byKey[key] = need
            }
        }
        var result = Array(byKey.values)

        // 有甲殼類過敏 → 移除海鮮過敏
        if result.contains(where: { $0.label == "甲殼類過敏" }) {
            result.removeAll { $0.label == "海鮮過敏" }
        }

        return result.sorted {
            if $0.category.sortOrder != $1.category.sortOrder {
                return $0.category.sortOrder < $1.category.sortOrder
            }
            return $0.sortKey < $1.sortKey
        }
    }

    // MARK: - AI 補充路徑

    @available(iOS 26, *)
    private static func supplementWithAI(remark: String, existing: [DietaryNeed]) async throws -> [DietaryNeed] {
        let existingLabels = existing.map { $0.label }.joined(separator: "、")
        let instructions = """
        你是旅遊領隊助理，負責補充飲食需求解析。

        rule-based 系統已能識別：過敏（花生、海鮮、堅果、麩質、乳糖、蛋）、素食類型、不吃特定肉類、機上特殊餐代碼（MOML/VGML等）、不吃辣、糖尿病飲食、低鈉飲食。

        你的任務：只補充原文中 rule-based 無法識別的需求，例如特殊醫療飲食、不常見的食物限制、自由描述的特殊需求。

        規則：
        - 如果原文的需求已全部被「已解析」涵蓋，回傳空陣列
        - 不推論、不猜測，原文沒有明確說明的不補充
        - 不重複已有的項目
        - 忽略電話號碼、姓名、日期等無關內容
        """

        let prompt = "原始備註：\(remark)\n已解析：\(existingLabels.isEmpty ? "（無）" : existingLabels)\n請補充："

        let result = try await FoundationModelManager.shared.generate(
            prompt: prompt,
            instructions: instructions,
            as: AIAnalyzedNeeds.self
        )

        let existingLabelSet = Set(existing.map { $0.label })
        let aiNeeds: [DietaryNeed] = result.needs.enumerated().compactMap { idx, need in
            guard !existingLabelSet.contains(need.label) else { return nil }
            let category = categoryFromString(need.category)
            let scope: DietaryScope = need.isAirborne ? .airborne : .tripWide
            let finalCategory: DietaryCategory = need.isAirborne ? .airlineMeal : category
            return DietaryNeed(category: finalCategory, label: need.label,
                               scope: scope, sortKey: existing.count + idx, isAIGenerated: true)
        }

        return existing + aiNeeds
    }

    private static func categoryFromString(_ s: String) -> DietaryCategory {
        switch s {
        case "過敏":         return .allergy
        case "素食":         return .vegetarian
        case "不吃特定食物": return .avoidFood
        case "機上特殊餐":   return .airlineMeal
        default:             return .allergy
        }
    }
}
