import Foundation
import PDFKit
import Vision
import UIKit

// MARK: - RawTable

struct RawTable {
    var rows: [[String]]

    var isEmpty: Bool { rows.isEmpty }
    var rowCount: Int { rows.count }

    var maxColumnCount: Int {
        rows.map { $0.count }.max() ?? 0
    }

    func normalized() -> RawTable {
        let maxCols = maxColumnCount
        guard maxCols > 0 else { return self }
        let normalized = rows.map { row -> [String] in
            if row.count >= maxCols { return row }
            return row + Array(repeating: "", count: maxCols - row.count)
        }
        return RawTable(rows: normalized)
    }
}

// MARK: - ParserError

enum ParserError: LocalizedError {
    case unsupportedFormat
    case fileReadFailed
    case noDataFound

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支援的檔案格式（支援 xlsx、docx、pdf）"
        case .fileReadFailed:    return "無法讀取檔案內容"
        case .noDataFound:       return "未能從檔案中找到任何表格資料"
        }
    }
}

// MARK: - TourMemberParser

struct TourMemberParser {

    // MARK: - 公開入口

    static func extractTables(from url: URL) throws -> [RawTable] {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "xlsx": return try extractFromXLSX(url: url)
        case "docx": return try extractFromDOCX(url: url)
        case "pdf":  return try extractFromPDF(url: url)
        default:     throw ParserError.unsupportedFormat
        }
    }

    static func extractTables(from image: UIImage) async throws -> [RawTable] {
        let lines = try await recognizeText(from: image)
        return [RawTable(rows: lines.map { [$0] })]
    }

    // MARK: - XLSX
    // 策略：完全不依賴 CoreXLSX 的 relationship 解析
    // 直接從 ZIP 讀取 xl/sharedStrings.xml 和 xl/worksheets/sheet1.xml
    // 用自己的 XMLParser 解析，移除 namespace 避免問題

    private static func extractFromXLSX(url: URL) throws -> [RawTable] {
        guard let zipData = try? Data(contentsOf: url) else {
            throw ParserError.fileReadFailed
        }

        // Step 1: 解析 sharedStrings
        let sharedStrings = parseSharedStrings(from: zipData)

        // Step 2: 找 worksheet（試幾個常見路徑）
        let worksheetPaths = [
            "xl/worksheets/sheet1.xml",
            "xl/worksheets/Sheet1.xml",
            "xl/worksheets/sheet.xml"
        ]

        var worksheetData: Data? = nil
        for path in worksheetPaths {
            if let data = extractFileFromZip(zipData: zipData, path: path) {
                worksheetData = data
                break
            }
        }

        guard let wsData = worksheetData else {
            throw ParserError.fileReadFailed
        }

        // Step 3: 解析 worksheet，得到 rowIndex → [colIndex: value]
        let rowMap = parseWorksheet(data: wsData, sharedStrings: sharedStrings)

        guard !rowMap.isEmpty else { throw ParserError.noDataFound }

        // Step 4: 轉成 [[String]]，按欄位對齊
        let maxCol = rowMap.values.compactMap { $0.keys.max() }.max() ?? 0
        let sortedRows = rowMap.keys.sorted().map { rowIdx -> [String] in
            let colMap = rowMap[rowIdx] ?? [:]
            return (0...maxCol).map { colIdx in colMap[colIdx] ?? "" }
        }

        let table = RawTable(rows: sortedRows)
        guard !table.isEmpty else { throw ParserError.noDataFound }

        return splitIntoTables(table)
    }

    /// 從 ZIP 解出 xl/sharedStrings.xml 並解析成字串陣列
    /// 關鍵：移除 namespace 後，對所有 <si> 找 <t>（包含 rich text 的 <r><t>）
    private static func parseSharedStrings(from zipData: Data) -> [String] {
        guard let xmlData = extractFileFromZip(zipData: zipData, path: "xl/sharedStrings.xml"),
              var xmlString = String(data: xmlData, encoding: .utf8) else {
            return []
        }

        // 移除 namespace 宣告，讓 XMLParser 直接用 local name 比對
        xmlString = removeXMLNamespace(xmlString)

        guard let cleanData = xmlString.data(using: .utf8) else { return [] }

        let parser = SharedStringsXMLParser()
        let xmlParser = XMLParser(data: cleanData)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.strings
    }

    /// 解析 worksheet XML，回傳 rowIndex → [colIndex: value]
    private static func parseWorksheet(data: Data, sharedStrings: [String]) -> [Int: [Int: String]] {
        guard var xmlString = String(data: data, encoding: .utf8) else { return [:] }

        xmlString = removeXMLNamespace(xmlString)

        guard let cleanData = xmlString.data(using: .utf8) else { return [:] }

        let parser = WorksheetXMLParser(sharedStrings: sharedStrings)
        let xmlParser = XMLParser(data: cleanData)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.rowMap
    }

    /// 移除 XML 的 default namespace 宣告（避免 XMLParser 的 namespace 問題）
    private static func removeXMLNamespace(_ xml: String) -> String {
        // 移除 xmlns="..." 和 xmlns:prefix="..." 宣告
        var result = xml
        // 移除 default namespace
        result = result.replacingOccurrences(
            of: " xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
            with: ""
        )
        // 用 regex 移除其他 xmlns 宣告
        if let regex = try? NSRegularExpression(pattern: #" xmlns(?::\w+)?="[^"]*""#) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        return result
    }

    // MARK: - DOCX

    private static func extractFromDOCX(url: URL) throws -> [RawTable] {
        guard let zipData = try? Data(contentsOf: url),
              let xmlData = extractFileFromZip(zipData: zipData, path: "word/document.xml") else {
            throw ParserError.fileReadFailed
        }

        // docx 用 w: prefix，移除 prefix 讓 XMLParser 直接比對
        guard var xmlString = String(data: xmlData, encoding: .utf8) else {
            throw ParserError.fileReadFailed
        }

        // 移除所有 namespace 宣告和 w: prefix
        xmlString = removeXMLNamespace(xmlString)
        // 移除 w: prefix（保留元素名稱）
        xmlString = xmlString.replacingOccurrences(of: "w:", with: "")
        // 移除其他常見 prefix
        for prefix in ["r:", "mc:", "m:", "o:", "v:", "wp:", "a:", "pic:", "p:", "wps:", "wpc:"] {
            xmlString = xmlString.replacingOccurrences(of: prefix, with: "")
        }

        guard let cleanData = xmlString.data(using: .utf8) else {
            throw ParserError.fileReadFailed
        }

        let parser = DocXMLParser()
        let xmlParser = XMLParser(data: cleanData)
        xmlParser.delegate = parser
        xmlParser.parse()

        let tables = parser.tables
            .map { RawTable(rows: $0) }
            .filter { !$0.isEmpty }
            .sorted { $0.rowCount > $1.rowCount }

        guard !tables.isEmpty else { throw ParserError.noDataFound }
        return tables
    }

    // MARK: - PDF（目前 UI 不會觸發，保留備用）

        private static func extractFromPDF(url: URL) throws -> [RawTable] {
            guard let doc = PDFDocument(url: url) else {
                throw ParserError.fileReadFailed
            }

            var lines: [String] = []
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i), let text = page.string else { continue }
                let pageLines = text
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                lines.append(contentsOf: pageLines)
            }

            guard !lines.isEmpty else { throw ParserError.noDataFound }
            return [RawTable(rows: lines.map { [$0] })]
        }

    // MARK: - Vision OCR

    private static func recognizeText(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw ParserError.fileReadFailed }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let lines = req.results?
                    .compactMap { $0 as? VNRecognizedTextObservation }
                    .compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    ?? []
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US"]
            request.usesLanguageCorrection = true

            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - 表格分割

    private static func splitIntoTables(_ table: RawTable) -> [RawTable] {
        let headerKeywords = ["name", "passport", "姓名", "護照", "room", "english",
                              "chinese", "birth", "remark", "備註", "title"]

        var dataStartIndex: Int? = nil
        for (i, row) in table.rows.enumerated() {
            let joined = row.joined(separator: " ").lowercased()
            if headerKeywords.contains(where: { joined.contains($0) }) {
                dataStartIndex = i
                break
            }
        }

        guard let startIdx = dataStartIndex else {
            return [table]
        }

        var result: [RawTable] = []
        if startIdx > 0 {
            result.append(RawTable(rows: Array(table.rows[0..<startIdx])))
        }
        result.append(RawTable(rows: Array(table.rows[startIdx...])))
        return result.sorted { $0.rowCount > $1.rowCount }
    }

    // MARK: - ZIP 解壓

    static func extractFileFromZip(zipData: Data, path: String) -> Data? {
        let bytes = [UInt8](zipData)
        let count = bytes.count
        var i = 0

        while i + 30 < count {
            guard bytes[i] == 0x50, bytes[i+1] == 0x4B,
                  bytes[i+2] == 0x03, bytes[i+3] == 0x04 else {
                i += 1
                continue
            }

            let compression = UInt16(bytes[i+8]) | (UInt16(bytes[i+9]) << 8)
            let compressedSize = Int(
                UInt32(bytes[i+18]) | (UInt32(bytes[i+19]) << 8) |
                (UInt32(bytes[i+20]) << 16) | (UInt32(bytes[i+21]) << 24)
            )
            let nameLen  = Int(UInt16(bytes[i+26]) | (UInt16(bytes[i+27]) << 8))
            let extraLen = Int(UInt16(bytes[i+28]) | (UInt16(bytes[i+29]) << 8))

            guard i + 30 + nameLen <= count else { break }

            let fileName = String(bytes: Array(bytes[(i+30)..<(i+30+nameLen)]), encoding: .utf8) ?? ""
            let dataStart = i + 30 + nameLen + extraLen

            if fileName == path {
                guard dataStart + max(compressedSize, 0) <= count else { break }
                let fileData = Data(bytes[dataStart..<(dataStart + compressedSize)])
                switch compression {
                case 0: return fileData
                case 8: return inflate(fileData)
                default: return nil
                }
            }

            i = dataStart + max(compressedSize, 0)
        }
        return nil
    }

    // 相容舊呼叫（extractFromDOCX 用）
    static func extractFromZip(data: Data, filename: String) -> Data? {
        extractFileFromZip(zipData: data, path: filename)
    }

    private static func inflate(_ data: Data) -> Data? {
        return try? (data as NSData).decompressed(using: .zlib) as Data
    }

    // MARK: - 欄名轉索引（A→0, B→1, Z→25, AA→26）

    static func columnToIndex(_ col: String) -> Int {
        col.uppercased().unicodeScalars.reduce(0) { acc, scalar in
            acc * 26 + Int(scalar.value - 64)
        } - 1
    }
}

// MARK: - XMLParser: SharedStrings
// 解析 xl/sharedStrings.xml
// 每個 <si> 是一個字串，文字在 <t> 裡（可能直接在 <si> 或在 <r><t> 裡）

private class SharedStringsXMLParser: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var inSI = false
    private var inT  = false
    private var currentSI = ""
    private var currentT  = ""

    func parser(_ parser: XMLParser, didStartElement el: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        switch el {
        case "si": inSI = true; currentSI = ""
        case "t" where inSI: inT = true; currentT = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inT { currentT += string }
    }

    func parser(_ parser: XMLParser, didEndElement el: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch el {
        case "t" where inSI:
            currentSI += currentT
            inT = false
        case "si":
            strings.append(currentSI)
            inSI = false
        default: break
        }
    }
}

// MARK: - XMLParser: Worksheet
// 解析 xl/worksheets/sheet1.xml
// 回傳 rowIndex → [colIndex: value]

private class WorksheetXMLParser: NSObject, XMLParserDelegate {
    var rowMap: [Int: [Int: String]] = [:]

    private let sharedStrings: [String]
    private var currentRow  = 0
    private var currentCol  = 0
    private var currentType = ""   // "s" = sharedString, "" = number/date/other
    private var currentVal  = ""
    private var inV = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement el: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        switch el {
        case "row":
            if let r = attributes["r"], let rowIdx = Int(r) {
                currentRow = rowIdx
            }
        case "c":
            // ref 例如 "A9", "B11"
            if let ref = attributes["r"] {
                let colStr = ref.prefix(while: { $0.isLetter })
                currentCol = TourMemberParser.columnToIndex(String(colStr))
            }
            currentType = attributes["t"] ?? ""
            currentVal  = ""
        case "v":
            inV = true; currentVal = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inV { currentVal += string }
    }

    func parser(_ parser: XMLParser, didEndElement el: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard el == "v" || el == "c" else { return }

        if el == "v" {
            inV = false
            return
        }

        // el == "c"：儲存解析結果
        let value: String
        if currentType == "s" {
            // shared string：currentVal 是 index
            let idx = Int(currentVal) ?? -1
            value = (idx >= 0 && idx < sharedStrings.count)
                ? sharedStrings[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
        } else {
            value = currentVal.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !value.isEmpty {
            if rowMap[currentRow] == nil { rowMap[currentRow] = [:] }
            rowMap[currentRow]![currentCol] = value
        }
    }
}

// MARK: - XMLParser: DOCX Tables

private class DocXMLParser: NSObject, XMLParserDelegate {
    var tables: [[[String]]] = []
    private var currentTable: [[String]] = []
    private var currentRow:   [String]   = []
    private var currentCell   = ""
    private var currentText   = ""
    private var inCell = false

    func parser(_ parser: XMLParser, didStartElement el: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        switch el {
        case "tbl": currentTable = []
        case "tr":  currentRow   = []
        case "tc":  inCell = true; currentCell = ""
        case "p":   currentText  = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inCell { currentText += string }
    }

    func parser(_ parser: XMLParser, didEndElement el: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch el {
        case "p":
            if inCell { currentCell += currentText }
            currentText = ""
        case "tc":
            currentRow.append(currentCell.trimmingCharacters(in: .whitespacesAndNewlines))
            currentCell = ""; inCell = false
        case "tr":
            if !currentRow.allSatisfy({ $0.isEmpty }) { currentTable.append(currentRow) }
            currentRow = []
        case "tbl":
            if !currentTable.isEmpty { tables.append(currentTable) }
            currentTable = []
        default: break
        }
    }
}
