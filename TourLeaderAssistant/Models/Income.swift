import SwiftUI
import SwiftData

enum IncomeType: String, Codable, CaseIterable {
    case leaderTip = "leaderTip"
    case perDiem = "perDiem"
    case commission = "commission"
    case other = "other"

    var displayName: String {
        switch self {
        case .leaderTip: return "領隊小費"
        case .perDiem: return "出差費"
        case .commission: return "佣金"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .leaderTip: return "hand.thumbsup"
        case .perDiem: return "suitcase"
        case .commission: return "percent"
        case .other: return "plus.circle"
        }
    }
}

@Model
class Income {
    var id: UUID
    var teamID: UUID
    var date: Date
    var type: IncomeType
    var typeCustom: String?
    var amount: Decimal
    var currency: String
    var notes: String?
    var createdAt: Date

    init(
        teamID: UUID,
        date: Date = Date(),
        type: IncomeType,
        amount: Decimal,
        currency: String
    ) {
        self.id = UUID()
        self.teamID = teamID
        self.date = date
        self.type = type
        self.amount = amount
        self.currency = currency
        self.createdAt = Date()
    }

    var displayName: String {
        type == .other ? (typeCustom ?? "其他") : type.displayName
    }
}
