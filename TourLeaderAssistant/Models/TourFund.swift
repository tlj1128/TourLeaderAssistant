import Foundation
import SwiftData

@Model
class TourFund {
    var id: UUID
    var teamID: UUID
    var typeName: String
    var currency: String
    var initialAmount: Decimal
    var isReimbursable: Bool
    var notes: String?

    init(
        teamID: UUID,
        typeName: String,
        currency: String,
        initialAmount: Decimal,
        isReimbursable: Bool = true
    ) {
        self.id = UUID()
        self.teamID = teamID
        self.typeName = typeName
        self.currency = currency
        self.initialAmount = initialAmount
        self.isReimbursable = isReimbursable
    }
}

// 預設類型，不存資料庫
struct DefaultFundType {
    let name: String
    let iconName: String

    static let all: [DefaultFundType] = [
        DefaultFundType(name: "零用金", iconName: "bag"),
        DefaultFundType(name: "誤餐費", iconName: "fork.knife"),
        DefaultFundType(name: "導遊小費", iconName: "hand.thumbsup"),
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
