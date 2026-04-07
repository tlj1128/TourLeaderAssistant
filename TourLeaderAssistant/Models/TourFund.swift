import Foundation
import SwiftData

@Model
class TourFund {
    var id: UUID
    var teamID: UUID
    var fundType: FundType
    var fundTypeCustom: String?
    var currency: String
    var initialAmount: Decimal
    var isReimbursable: Bool
    var notes: String?

    init(
        teamID: UUID,
        fundType: FundType,
        currency: String,
        initialAmount: Decimal,
        isReimbursable: Bool = true
    ) {
        self.id = UUID()
        self.teamID = teamID
        self.fundType = fundType
        self.currency = currency
        self.initialAmount = initialAmount
        self.isReimbursable = isReimbursable
    }
}

enum FundType: String, Codable {
    case pettyCash = "pettyCash"
    case mealAllowance = "mealAllowance"
    case guideTip = "guideTip"
    case other = "other"

    var displayName: String {
        switch self {
        case .pettyCash: return "零用金"
        case .mealAllowance: return "誤餐費"
        case .guideTip: return "導遊小費"
        case .other: return "其他"
        }
    }
}
