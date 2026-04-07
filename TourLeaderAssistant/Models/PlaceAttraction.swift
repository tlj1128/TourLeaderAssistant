import Foundation
import SwiftData

@Model
class PlaceAttraction {
    var id: UUID
    var nameEN: String
    var nameZH: String
    var nameLocal: String
    var city: City?
    var address: String
    var phone: String
    var ticketPrice: String
    var openingHours: String
    var photographyRules: String
    var allowedItems: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    var remoteID: UUID?
    var needsSync: Bool

    init(nameEN: String, city: City? = nil) {
        self.id = UUID()
        self.nameEN = nameEN
        self.nameZH = ""
        self.nameLocal = ""
        self.city = city
        self.address = ""
        self.phone = ""
        self.ticketPrice = ""
        self.openingHours = ""
        self.photographyRules = ""
        self.allowedItems = ""
        self.notes = ""
        self.createdAt = Date()
        self.updatedAt = Date()
        self.remoteID = nil
        self.needsSync = true
    }

    var displayName: String { nameEN }
    var displaySubtitle: String? { nameZH.isEmpty ? nil : nameZH }
}
