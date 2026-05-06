import Foundation
import SwiftData

@Model
class PlaceHotel {
    var id: UUID
    var nameEN: String
    var nameZH: String
    var city: City?
    var address: String
    var phone: String

    var floorsAndHoursData: String
    var wifiData: String
    var phoneDialingData: String
    var amenitiesData: String

    var surroundingsAndNotes: String
    var createdAt: Date
    var updatedAt: Date

    var remoteID: UUID?
    var needsSync: Bool

    init(nameEN: String, city: City? = nil) {
        self.id = UUID()
        self.nameEN = nameEN
        self.nameZH = ""
        self.city = city
        self.address = ""
        self.phone = ""
        self.floorsAndHoursData = "{}"
        self.wifiData = "{}"
        self.phoneDialingData = "{}"
        self.amenitiesData = "{}"
        self.surroundingsAndNotes = ""
        self.createdAt = Date()
        self.updatedAt = Date()
        self.remoteID = nil
        self.needsSync = true
    }

    // 英文優先：列表與詳細頁主標題用英文
    var displayName: String { nameEN }

    // 有中文名稱時顯示於副標題
    var displaySubtitle: String? { nameZH.isEmpty ? nil : nameZH }

    @MainActor
    var floorsAndHours: FloorsAndHours {
        get {
            guard let data = floorsAndHoursData.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(FloorsAndHours.self, from: data) else {
                return FloorsAndHours()
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                floorsAndHoursData = string
            }
        }
    }

    @MainActor
    var wifi: HotelWifi {
        get {
            guard let data = wifiData.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(HotelWifi.self, from: data) else {
                return HotelWifi()
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                wifiData = string
            }
        }
    }

    @MainActor
    var phoneDialing: PhoneDialing {
        get {
            guard let data = phoneDialingData.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(PhoneDialing.self, from: data) else {
                return PhoneDialing()
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                phoneDialingData = string
            }
        }
    }

    @MainActor
    var amenities: HotelAmenities {
        get {
            guard let data = amenitiesData.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(HotelAmenities.self, from: data) else {
                return HotelAmenities()
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                amenitiesData = string
            }
        }
    }

}
