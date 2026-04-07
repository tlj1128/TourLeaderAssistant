import Foundation
import SwiftData

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
    var receiptImagePath: String?
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
        self.convertedAmount = (amount * quantity) / exchangeRate
        self.createdAt = Date()
    }
}
