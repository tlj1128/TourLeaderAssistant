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
    var createdBy: String        // Keychain 裝置 UUID，留給未來 RLS 使用

    var remoteURL: String?
    var needsUpload: Bool
    var needsDelete: Bool        // 標記待從雲端刪除，同步完成後才真正刪除本機記錄

    init(placeID: UUID, fileName: String, category: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.placeID = placeID
        self.fileName = fileName
        self.category = category
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.createdBy = KeychainManager.deviceUUID
        self.needsUpload = true
        self.needsDelete = false
    }
}
