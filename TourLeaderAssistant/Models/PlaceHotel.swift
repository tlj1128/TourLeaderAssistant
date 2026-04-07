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

    var floorsAndHours: FloorsAndHours {
        get { Self.decode(FloorsAndHours.self, from: floorsAndHoursData) ?? FloorsAndHours() }
        set { floorsAndHoursData = Self.encode(newValue) }
    }

    var wifi: HotelWifi {
        get { Self.decode(HotelWifi.self, from: wifiData) ?? HotelWifi() }
        set { wifiData = Self.encode(newValue) }
    }

    var phoneDialing: PhoneDialing {
        get { Self.decode(PhoneDialing.self, from: phoneDialingData) ?? PhoneDialing() }
        set { phoneDialingData = Self.encode(newValue) }
    }

    var amenities: HotelAmenities {
        get { Self.decode(HotelAmenities.self, from: amenitiesData) ?? HotelAmenities() }
        set { amenitiesData = Self.encode(newValue) }
    }

    private nonisolated static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private nonisolated static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}
