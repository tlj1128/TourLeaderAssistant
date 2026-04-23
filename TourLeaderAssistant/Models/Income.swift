import Foundation
import SwiftData

@Model
class Income {
    var id: UUID
    var teamID: UUID
    var date: Date
    var typeName: String
    var amount: Decimal
    var currency: String
    var notes: String?
    var createdAt: Date

    init(
        teamID: UUID,
        date: Date = Date(),
        typeName: String,
        amount: Decimal,
        currency: String
    ) {
        self.id = UUID()
        self.teamID = teamID
        self.date = date
        self.typeName = typeName
        self.amount = amount
        self.currency = currency
        self.createdAt = Date()
    }
}

// 預設類型，不存資料庫
struct DefaultIncomeType {
    let name: String
    let iconName: String

    static let all: [DefaultIncomeType] = [
        DefaultIncomeType(name: "領隊服務費", iconName: "hand.thumbsup"),
        DefaultIncomeType(name: "出差費",   iconName: "suitcase"),
        DefaultIncomeType(name: "佣金",     iconName: "percent"),
    ]

    static let otherName = "其他"
    static let otherIcon = "ellipsis.circle"

    static func iconName(for typeName: String) -> String {
        if let match = all.first(where: { $0.name == typeName }) {
            return match.iconName
        }
        return otherIcon
    }
}
