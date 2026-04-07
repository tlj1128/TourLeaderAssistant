import Foundation
import SwiftData

@Model
class Country {
    var id: UUID
    var nameZH: String
    var nameEN: String
    var code: String
    var phoneCode: String
    var currencyCode: String  // ISO 4217，例如 JPY、EUR、USD
    var lastUsedAt: Date?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \City.country)
    var cities: [City] = []

    init(nameZH: String, nameEN: String, code: String, phoneCode: String = "", currencyCode: String = "") {
        self.id = UUID()
        self.nameZH = nameZH
        self.nameEN = nameEN
        self.code = code
        self.phoneCode = phoneCode
        self.currencyCode = currencyCode
        self.createdAt = Date()
    }

    var displayName: String { nameZH.isEmpty ? nameEN : nameZH }
}
