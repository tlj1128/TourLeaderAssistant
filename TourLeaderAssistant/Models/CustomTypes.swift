import Foundation
import SwiftData

@Model
class CustomFundType {
    var id: UUID
    var name: String
    var iconName: String   // SF Symbols，UI 暫未開放選擇
    var sortOrder: Int
    var createdAt: Date

    init(name: String, iconName: String = "tag", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

@Model
class CustomIncomeType {
    var id: UUID
    var name: String
    var iconName: String   // SF Symbols，UI 暫未開放選擇
    var sortOrder: Int
    var createdAt: Date

    init(name: String, iconName: String = "tag", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
