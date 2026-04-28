import Foundation

struct FloorsAndHours: Codable, Sendable {
    var lobbyFloor: String = ""
    var poolFloor: String = ""
    var gymFloor: String = ""
    var breakfastRestaurantFloor: String = ""
    var dinnerRestaurantFloor: String = ""
    var breakfastHours: String = ""
    var dinnerHours: String = ""
    var poolHours: String = ""
    var gymHours: String = ""
}

struct HotelWifi: Codable, Sendable {
    var network: String = ""
    var password: String = ""
    var loginMethod: String = ""
}

struct PhoneDialing: Codable, Sendable {
    var roomToFront: String = ""
    var roomToRoom: String = ""
    var outsideLine: String = ""
    var notes: String = ""
}

struct HotelAmenities: Codable, Sendable {
    var roomAmenities: [String] = []
    var hotelFacilities: [String] = []
}

enum RoomAmenity: String, CaseIterable, Sendable {
    case bathtub = "浴缸"
    case hairDryer = "吹風機"
    case slippers = "拖鞋"
    case safe = "保險箱"
    case bathrobes = "浴袍"
    case minibar = "迷你冰箱"
    case kettle = "電熱水壺"
    case toothbrush = "牙刷牙膏"
    case razor = "刮鬍刀"
}

enum HotelFacility: String, CaseIterable, Sendable {
    case pool = "游泳池"
    case gym = "健身房"
    case laundry = "洗衣房"
    case spa = "SPA"
    case restaurant = "餐廳"
    case bar = "酒吧"
    case businessCenter = "商務中心"
    case parking = "停車場"
    case concierge = "禮賓服務"
}
