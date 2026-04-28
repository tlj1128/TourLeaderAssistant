import Foundation
import SwiftData

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "現金"
    case creditCard = "信用卡"
    case other = "其他"
}

@Model
class Expense {
    var id: UUID
    var teamID: UUID
    var date: Date
    var location: String?
    var item: String
    var quantity: Decimal
    var amount: Decimal
    var currency: String
    var exchangeRate: Decimal
    var convertedAmount: Decimal
    var receiptNumber: String?
    var receiptImagePathsData: String  // JSON 陣列，例如 ["uuid1.jpg","uuid2.jpg"]
    var paymentMethod: String?
    var notes: String?
    var createdAt: Date

    init(
        teamID: UUID,
        item: String,
        quantity: Decimal,
        amount: Decimal,
        currency: String,
        exchangeRate: Decimal,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.teamID = teamID
        self.date = date
        self.item = item
        self.quantity = quantity
        self.amount = amount
        self.currency = currency
        self.exchangeRate = exchangeRate
        self.convertedAmount = exchangeRate == 0 ? 0 : (amount * quantity) / exchangeRate
        self.receiptImagePathsData = "[]"
        self.createdAt = Date()
    }

    // MARK: - Computed Property

    var receiptImagePaths: [String] {
        get {
            guard let data = receiptImagePathsData.data(using: .utf8),
                  let paths = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return paths
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let string = String(data: data, encoding: .utf8)
            else { return }
            receiptImagePathsData = string
        }
    }
}
