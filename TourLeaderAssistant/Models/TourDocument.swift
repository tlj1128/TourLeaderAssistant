import Foundation
import SwiftData

@Model
class TourDocument {
    var id: UUID
    var teamID: UUID
    var category: DocumentCategory
    var fileName: String
    var fileURL: URL
    var createdAt: Date

    init(
        teamID: UUID,
        category: DocumentCategory,
        fileName: String,
        fileURL: URL
    ) {
        self.id = UUID()
        self.teamID = teamID
        self.category = category
        self.fileName = fileName
        self.fileURL = fileURL
        self.createdAt = Date()
    }
}

enum DocumentCategory: String, Codable, CaseIterable {
    case itineraryCN = "itineraryCN"
    case itineraryEN = "itineraryEN"
    case mealPlan = "mealPlan"
    case guestList = "guestList"
    case roomingList = "roomingList"
    case ticket = "ticket"
    case visa = "visa"
    case other = "other"

    var displayName: String {
        switch self {
        case .itineraryCN: return "中文行程"
        case .itineraryEN: return "英文行程"
        case .mealPlan: return "餐表"
        case .guestList: return "團體大表"
        case .roomingList: return "分房表"
        case .ticket: return "電子機票"
        case .visa: return "簽證"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .itineraryCN: return "doc.text"
        case .itineraryEN: return "doc.text"
        case .mealPlan: return "fork.knife"
        case .guestList: return "person.2"
        case .roomingList: return "bed.double"
        case .ticket: return "airplane"
        case .visa: return "stamp"
        case .other: return "paperclip"
        }
    }
}
