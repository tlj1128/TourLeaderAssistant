import Foundation
import SwiftData

@Model
class City {
    var id: UUID
    var nameZH: String
    var nameEN: String
    var createdAt: Date

    var country: Country?

    init(nameZH: String, nameEN: String, country: Country) {
        self.id = UUID()
        self.nameZH = nameZH
        self.nameEN = nameEN
        self.country = country
        self.createdAt = Date()
    }

    var displayName: String { nameZH.isEmpty ? nameEN : nameZH }

    var fullDisplayName: String {
        if let country = country {
            return "\(country.displayName) · \(displayName)"
        }
        return displayName
    }
}
