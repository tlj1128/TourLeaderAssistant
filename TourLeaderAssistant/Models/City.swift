import Foundation
import SwiftData

@Model
class City {
    var id: UUID
    var nameZH: String
    var nameEN: String
    var isPreset: Bool
    var createdAt: Date
    var remoteID: UUID?

    var country: Country?

    init(nameZH: String, nameEN: String, country: Country, isPreset: Bool = false) {
        self.id = UUID()
        self.nameZH = nameZH
        self.nameEN = nameEN
        self.isPreset = isPreset
        self.country = country
        self.createdAt = Date()
        self.remoteID = nil
    }

    var displayName: String { nameZH.isEmpty ? nameEN : nameZH }

    var fullDisplayName: String {
        if let country = country {
            return "\(country.displayName) · \(displayName)"
        }
        return displayName
    }
}
