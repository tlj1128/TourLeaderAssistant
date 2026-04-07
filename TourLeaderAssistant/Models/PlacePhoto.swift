import Foundation
import SwiftData

@Model
class PlacePhoto {
    var id: UUID
    var placeID: UUID
    var fileName: String
    var category: String
    var sortOrder: Int
    var createdAt: Date

    var remoteURL: String?
    var needsUpload: Bool

    init(placeID: UUID, fileName: String, category: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.placeID = placeID
        self.fileName = fileName
        self.category = category
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.needsUpload = true
    }
}
