import Foundation

// MARK: - ParsedMember（解析預覽用暫存結構，不是 SwiftData Model）

struct ParsedMember: Identifiable {
    var id = UUID()
    var nameEN: String
    var nameZH: String?
    var gender: String?
    var birthday: Date?
    var passportNumber: String?
    var passportExpiry: Date?
    var roomLabel: String?
    var remark: String?
    var sortOrder: Int
}
