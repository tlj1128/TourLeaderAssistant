import Foundation
import SwiftData
import Supabase

private func sanitizeQuery(_ input: String) -> String {
    input
        .replacingOccurrences(of: "%", with: "\\%")
        .replacingOccurrences(of: "_", with: "\\_")
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: ".", with: " ")
}

// MARK: - 地點類別（獨立定義，供搜尋預覽使用）

enum PlaceCategoryType: String, CaseIterable {
    case hotel, restaurant, attraction

    var displayName: String {
        switch self {
        case .hotel: return "飯店"
        case .restaurant: return "餐廳"
        case .attraction: return "景點"
        }
    }

    var icon: String {
        switch self {
        case .hotel: return "bed.double"
        case .restaurant: return "fork.knife"
        case .attraction: return "camera"
        }
    }
}

// MARK: - 搜尋預覽資料結構（純 struct，不存入 SwiftData）

struct PlaceSearchPreview: Identifiable {
    var id: UUID { remoteID ?? localID }

    let localID: UUID
    let remoteID: UUID?
    let type: PlaceCategoryType
    let nameEN: String
    let nameZH: String?
    let cityNameEN: String
    let cityNameZH: String
    let countryCode: String
    let remoteUpdatedAt: Date

    var isLocal: Bool
    var localNeedsSync: Bool

    var displayName: String { nameEN }
    var displaySubtitle: String? { nameZH.flatMap { $0.isEmpty ? nil : $0 } }

    var locationText: String {
        let flag = countryCode.flag
        return "\(flag) \(cityNameEN)"
    }

    var badgeState: PlaceSearchBadgeState {
        if isLocal && localNeedsSync { return .local }
        if isLocal { return .saved }
        return .cloudOnly
    }
}

enum PlaceSearchBadgeState {
    case local
    case saved
    case cloudOnly
}

// MARK: - 搜尋預覽結果容器

struct PlaceSearchPreviews {
    var hotels: [PlaceSearchPreview] = []
    var restaurants: [PlaceSearchPreview] = []
    var attractions: [PlaceSearchPreview] = []

    var all: [PlaceSearchPreview] { hotels + restaurants + attractions }
    var isEmpty: Bool { hotels.isEmpty && restaurants.isEmpty && attractions.isEmpty }

    var hotelCount: Int { hotels.count }
    var restaurantCount: Int { restaurants.count }
    var attractionCount: Int { attractions.count }
}

// MARK: - SupabaseManager 擴充

extension SupabaseManager {

    // MARK: 本機搜尋（供 View 即時呼叫）

    func localHotelPreviews(query: String, context: ModelContext) -> [PlaceSearchPreview] {
        let descriptor = FetchDescriptor<PlaceHotel>()
        guard let hotels = try? context.fetch(descriptor) else { return [] }
        return hotels
            .filter {
                $0.nameEN.localizedCaseInsensitiveContains(query) ||
                $0.nameZH.localizedCaseInsensitiveContains(query)
            }
            .map { hotel in
                PlaceSearchPreview(
                    localID: hotel.id,
                    remoteID: hotel.remoteID,
                    type: .hotel,
                    nameEN: hotel.nameEN,
                    nameZH: hotel.nameZH.isEmpty ? nil : hotel.nameZH,
                    cityNameEN: hotel.city?.nameEN ?? "",
                    cityNameZH: hotel.city?.nameZH ?? "",
                    countryCode: hotel.city?.country?.code ?? "",
                    remoteUpdatedAt: hotel.updatedAt,
                    isLocal: true,
                    localNeedsSync: hotel.needsSync
                )
            }
    }

    func localRestaurantPreviews(query: String, context: ModelContext) -> [PlaceSearchPreview] {
        let descriptor = FetchDescriptor<PlaceRestaurant>()
        guard let restaurants = try? context.fetch(descriptor) else { return [] }
        return restaurants
            .filter {
                $0.nameEN.localizedCaseInsensitiveContains(query) ||
                $0.nameZH.localizedCaseInsensitiveContains(query)
            }
            .map { r in
                PlaceSearchPreview(
                    localID: r.id,
                    remoteID: r.remoteID,
                    type: .restaurant,
                    nameEN: r.nameEN,
                    nameZH: r.nameZH.isEmpty ? nil : r.nameZH,
                    cityNameEN: r.city?.nameEN ?? "",
                    cityNameZH: r.city?.nameZH ?? "",
                    countryCode: r.city?.country?.code ?? "",
                    remoteUpdatedAt: r.updatedAt,
                    isLocal: true,
                    localNeedsSync: r.needsSync
                )
            }
    }

    func localAttractionPreviews(query: String, context: ModelContext) -> [PlaceSearchPreview] {
        let descriptor = FetchDescriptor<PlaceAttraction>()
        guard let attractions = try? context.fetch(descriptor) else { return [] }
        return attractions
            .filter {
                $0.nameEN.localizedCaseInsensitiveContains(query) ||
                $0.nameZH.localizedCaseInsensitiveContains(query)
            }
            .map { a in
                PlaceSearchPreview(
                    localID: a.id,
                    remoteID: a.remoteID,
                    type: .attraction,
                    nameEN: a.nameEN,
                    nameZH: a.nameZH.isEmpty ? nil : a.nameZH,
                    cityNameEN: a.city?.nameEN ?? "",
                    cityNameZH: a.city?.nameZH ?? "",
                    countryCode: a.city?.country?.code ?? "",
                    remoteUpdatedAt: a.updatedAt,
                    isLocal: true,
                    localNeedsSync: a.needsSync
                )
            }
    }

    // MARK: 雲端預覽搜尋（不存入本機）

    func searchPlacePreviews(query: String, context: ModelContext) async -> PlaceSearchPreviews {
        let normalized = query.trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return PlaceSearchPreviews() }

        async let remoteHotels = fetchRemoteHotelPreviews(query: normalized, context: context)
        async let remoteRestaurants = fetchRemoteRestaurantPreviews(query: normalized, context: context)
        async let remoteAttractions = fetchRemoteAttractionPreviews(query: normalized, context: context)

        let localHotels = localHotelPreviews(query: normalized, context: context)
        let localRestaurants = localRestaurantPreviews(query: normalized, context: context)
        let localAttractions = localAttractionPreviews(query: normalized, context: context)

        return PlaceSearchPreviews(
            hotels: mergePreviews(local: localHotels, remote: await remoteHotels),
            restaurants: mergePreviews(local: localRestaurants, remote: await remoteRestaurants),
            attractions: mergePreviews(local: localAttractions, remote: await remoteAttractions)
        )
    }

    private func fetchRemoteHotelPreviews(query: String, context: ModelContext) async -> [PlaceSearchPreview] {
        do {
            let q = sanitizeQuery(query)
            let results: [RemoteHotelPreview] = try await client
                .from("places_hotel")
                .select("id, name_en, name_zh, updated_at, cities(name_zh, name_en, countries(code))")
                .or("name_en.ilike.%\(q)%,name_zh.ilike.%\(q)%")
                .execute()
                .value

            return results.map { r in
                let remoteUUID = r.id
                let localDescriptor = FetchDescriptor<PlaceHotel>(
                    predicate: #Predicate { $0.remoteID == remoteUUID }
                )
                let isLocal = (try? context.fetch(localDescriptor).first) != nil
                return PlaceSearchPreview(
                    localID: r.id,
                    remoteID: r.id,
                    type: .hotel,
                    nameEN: r.nameEN,
                    nameZH: r.nameZH,
                    cityNameEN: r.cities.nameEN,
                    cityNameZH: r.cities.nameZH,
                    countryCode: r.cities.countries.code,
                    remoteUpdatedAt: r.updatedAt,
                    isLocal: isLocal,
                    localNeedsSync: false
                )
            }
        } catch {
            print("飯店雲端預覽搜尋失敗：\(error)")
            return []
        }
    }

    private func fetchRemoteRestaurantPreviews(query: String, context: ModelContext) async -> [PlaceSearchPreview] {
        do {
            let q = sanitizeQuery(query)
            let results: [RemoteRestaurantPreview] = try await client
                .from("places_restaurant")
                .select("id, name_en, name_zh, updated_at, cities(name_zh, name_en, countries(code))")
                .or("name_en.ilike.%\(q)%,name_zh.ilike.%\(q)%")
                .execute()
                .value

            return results.map { r in
                let remoteUUID = r.id
                let localDescriptor = FetchDescriptor<PlaceRestaurant>(
                    predicate: #Predicate { $0.remoteID == remoteUUID }
                )
                let isLocal = (try? context.fetch(localDescriptor).first) != nil
                return PlaceSearchPreview(
                    localID: r.id,
                    remoteID: r.id,
                    type: .restaurant,
                    nameEN: r.nameEN,
                    nameZH: r.nameZH,
                    cityNameEN: r.cities.nameEN,
                    cityNameZH: r.cities.nameZH,
                    countryCode: r.cities.countries.code,
                    remoteUpdatedAt: r.updatedAt,
                    isLocal: isLocal,
                    localNeedsSync: false
                )
            }
        } catch {
            print("餐廳雲端預覽搜尋失敗：\(error)")
            return []
        }
    }

    private func fetchRemoteAttractionPreviews(query: String, context: ModelContext) async -> [PlaceSearchPreview] {
        do {
            let q = sanitizeQuery(query)
            let results: [RemoteAttractionPreview] = try await client
                .from("places_attraction")
                .select("id, name_en, name_zh, updated_at, cities(name_zh, name_en, countries(code))")
                .or("name_en.ilike.%\(q)%,name_zh.ilike.%\(q)%")
                .execute()
                .value

            return results.map { r in
                let remoteUUID = r.id
                let localDescriptor = FetchDescriptor<PlaceAttraction>(
                    predicate: #Predicate { $0.remoteID == remoteUUID }
                )
                let isLocal = (try? context.fetch(localDescriptor).first) != nil
                return PlaceSearchPreview(
                    localID: r.id,
                    remoteID: r.id,
                    type: .attraction,
                    nameEN: r.nameEN,
                    nameZH: r.nameZH,
                    cityNameEN: r.cities.nameEN,
                    cityNameZH: r.cities.nameZH,
                    countryCode: r.cities.countries.code,
                    remoteUpdatedAt: r.updatedAt,
                    isLocal: isLocal,
                    localNeedsSync: false
                )
            }
        } catch {
            print("景點雲端預覽搜尋失敗：\(error)")
            return []
        }
    }

    private func mergePreviews(local: [PlaceSearchPreview], remote: [PlaceSearchPreview]) -> [PlaceSearchPreview] {
        var result = local
        let localIDs = Set(local.map { $0.id })
        for preview in remote where !localIDs.contains(preview.id) {
            result.append(preview)
        }
        return result
    }

    // MARK: 單筆下載

    func downloadHotel(remoteID: UUID, context: ModelContext) async -> Bool {
        do {
            let results: [RemoteHotel] = try await client
                .from("places_hotel")
                .select("*, cities(name_zh, name_en, countries(code))")
                .eq("id", value: remoteID.uuidString)
                .limit(1)
                .execute()
                .value

            guard let remote = results.first else { return false }

            let city = findOrCreateCityInExtension(
                nameZH: remote.cities.nameZH,
                nameEN: remote.cities.nameEN,
                countryCode: remote.cities.countries.code,
                remoteID: remote.cityID,
                context: context
            )
            let hotel = PlaceHotel(nameEN: remote.nameEN, city: city)
            hotel.remoteID = remote.id
            hotel.nameZH = remote.nameZH ?? ""
            hotel.address = remote.address ?? ""
            hotel.phone = remote.phone ?? ""
            hotel.floorsAndHoursData = jsonStringFromAnyCodable(remote.floorsAndHours)
            hotel.wifiData = jsonStringFromAnyCodable(remote.wifi)
            hotel.phoneDialingData = jsonStringFromAnyCodable(remote.phoneDialing)
            hotel.amenitiesData = jsonStringFromAnyCodable(remote.amenitiesAndFacilities)
            hotel.surroundingsAndNotes = remote.surroundingsAndNotes ?? ""
            hotel.updatedAt = remote.updatedAt
            hotel.needsSync = false
            context.insert(hotel)
            try? context.save()
            await downloadPhotosForPlace(placeID: hotel.id, placeRemoteID: remote.id, placeType: "hotel", context: context)
            try? context.save()
            return true
        } catch {
            print("飯店下載失敗：\(error)")
            return false
        }
    }

    func downloadRestaurant(remoteID: UUID, context: ModelContext) async -> Bool {
        do {
            let results: [RemoteRestaurant] = try await client
                .from("places_restaurant")
                .select("*, cities(name_zh, name_en, countries(code))")
                .eq("id", value: remoteID.uuidString)
                .limit(1)
                .execute()
                .value

            guard let remote = results.first else { return false }

            let city = findOrCreateCityInExtension(
                nameZH: remote.cities.nameZH,
                nameEN: remote.cities.nameEN,
                countryCode: remote.cities.countries.code,
                remoteID: remote.cityID,
                context: context
            )
            let restaurant = PlaceRestaurant(nameEN: remote.nameEN, city: city)
            restaurant.remoteID = remote.id
            restaurant.nameZH = remote.nameZH ?? ""
            restaurant.nameLocal = remote.nameLocal ?? ""
            restaurant.address = remote.address ?? ""
            restaurant.phone = remote.phone ?? ""
            restaurant.cuisine = remote.cuisine ?? ""
            restaurant.rating = remote.rating ?? ""
            restaurant.specialty = remote.specialty ?? ""
            restaurant.notes = remote.notes ?? ""
            restaurant.updatedAt = remote.updatedAt
            restaurant.needsSync = false
            context.insert(restaurant)
            try? context.save()
            await downloadPhotosForPlace(placeID: restaurant.id, placeRemoteID: remote.id, placeType: "restaurant", context: context)
            try? context.save()
            return true
        } catch {
            print("餐廳下載失敗：\(error)")
            return false
        }
    }

    func downloadAttraction(remoteID: UUID, context: ModelContext) async -> Bool {
        do {
            let results: [RemoteAttraction] = try await client
                .from("places_attraction")
                .select("*, cities(name_zh, name_en, countries(code))")
                .eq("id", value: remoteID.uuidString)
                .limit(1)
                .execute()
                .value

            guard let remote = results.first else { return false }

            let city = findOrCreateCityInExtension(
                nameZH: remote.cities.nameZH,
                nameEN: remote.cities.nameEN,
                countryCode: remote.cities.countries.code,
                remoteID: remote.cityID,
                context: context
            )
            let attraction = PlaceAttraction(nameEN: remote.nameEN, city: city)
            attraction.remoteID = remote.id
            attraction.nameZH = remote.nameZH ?? ""
            attraction.nameLocal = remote.nameLocal ?? ""
            attraction.address = remote.address ?? ""
            attraction.phone = remote.phone ?? ""
            attraction.ticketPrice = remote.ticketPrice ?? ""
            attraction.openingHours = remote.openingHours ?? ""
            attraction.photographyRules = remote.photographyRules ?? ""
            attraction.allowedItems = remote.allowedItems ?? ""
            attraction.notes = remote.notes ?? ""
            attraction.updatedAt = remote.updatedAt
            attraction.needsSync = false
            context.insert(attraction)
            try? context.save()
            await downloadPhotosForPlace(placeID: attraction.id, placeRemoteID: remote.id, placeType: "attraction", context: context)
            try? context.save()
            return true
        } catch {
            print("景點下載失敗：\(error)")
            return false
        }
    }

    // MARK: - 下載地點照片（下載地點時順帶呼叫）

    func downloadPhotosForPlace(placeID: UUID, placeRemoteID: UUID, placeType: String, context: ModelContext) async {
        let remotePhotos = await fetchRemotePhotoRecords(placeRemoteID: placeRemoteID, placeType: placeType)
        guard !remotePhotos.isEmpty else { return }

        for remotePhoto in remotePhotos {
            let url = publicURL(for: remotePhoto.storagePath)
            let success = await downloadAndCachePhoto(remoteURL: url, fileName: remotePhoto.fileName)
            if success {
                let photo = PlacePhoto(
                    placeID: placeID,
                    fileName: remotePhoto.fileName,
                    category: "",
                    sortOrder: remotePhoto.sortOrder
                )
                photo.remoteURL = url
                photo.needsUpload = false
                context.insert(photo)
            }
        }
    }

    // MARK: - 刪除本機地點時順帶刪照片

    func deleteLocalPhotos(for placeID: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<PlacePhoto>(
            predicate: #Predicate { $0.placeID == placeID }
        )
        guard let photos = try? context.fetch(descriptor) else { return }
        for photo in photos {
            PlacePhotoManager.shared.delete(fileName: photo.fileName)
            context.delete(photo)
        }
    }

    // MARK: - 更新本地單筆（從雲端重新下載覆蓋本機）

    func refreshLocalHotel(_ hotel: PlaceHotel, context: ModelContext) async -> Bool {
        guard let remoteID = hotel.remoteID else { return false }
        do {
            let results: [RemoteHotel] = try await client
                .from("places_hotel")
                .select("*, cities(name_zh, name_en, countries(code))")
                .eq("id", value: remoteID.uuidString)
                .limit(1)
                .execute()
                .value

            guard let remote = results.first else { return false }

            hotel.nameEN = remote.nameEN
            hotel.nameZH = remote.nameZH ?? ""
            hotel.address = remote.address ?? ""
            hotel.phone = remote.phone ?? ""
            hotel.floorsAndHoursData = jsonStringFromAnyCodable(remote.floorsAndHours)
            hotel.wifiData = jsonStringFromAnyCodable(remote.wifi)
            hotel.phoneDialingData = jsonStringFromAnyCodable(remote.phoneDialing)
            hotel.amenitiesData = jsonStringFromAnyCodable(remote.amenitiesAndFacilities)
            hotel.surroundingsAndNotes = remote.surroundingsAndNotes ?? ""
            hotel.updatedAt = remote.updatedAt
            hotel.needsSync = false
            try? context.save()

            // 同步照片：清除本機照片，重新從雲端下載
            deleteLocalPhotos(for: hotel.id, context: context)
            try? context.save()
            await downloadPhotosForPlace(placeID: hotel.id, placeRemoteID: remoteID, placeType: "hotel", context: context)
            try? context.save()
            return true
        } catch {
            print("飯店更新本地失敗：\(error)")
            return false
        }
    }

    func refreshLocalRestaurant(_ restaurant: PlaceRestaurant, context: ModelContext) async -> Bool {
        guard let remoteID = restaurant.remoteID else { return false }
        do {
            let results: [RemoteRestaurant] = try await client
                .from("places_restaurant")
                .select("*, cities(name_zh, name_en, countries(code))")
                .eq("id", value: remoteID.uuidString)
                .limit(1)
                .execute()
                .value

            guard let remote = results.first else { return false }

            restaurant.nameEN = remote.nameEN
            restaurant.nameZH = remote.nameZH ?? ""
            restaurant.nameLocal = remote.nameLocal ?? ""
            restaurant.address = remote.address ?? ""
            restaurant.phone = remote.phone ?? ""
            restaurant.cuisine = remote.cuisine ?? ""
            restaurant.rating = remote.rating ?? ""
            restaurant.specialty = remote.specialty ?? ""
            restaurant.notes = remote.notes ?? ""
            restaurant.updatedAt = remote.updatedAt
            restaurant.needsSync = false
            try? context.save()

            deleteLocalPhotos(for: restaurant.id, context: context)
            try? context.save()
            await downloadPhotosForPlace(placeID: restaurant.id, placeRemoteID: remoteID, placeType: "restaurant", context: context)
            try? context.save()
            return true
        } catch {
            print("餐廳更新本地失敗：\(error)")
            return false
        }
    }

    func refreshLocalAttraction(_ attraction: PlaceAttraction, context: ModelContext) async -> Bool {
        guard let remoteID = attraction.remoteID else { return false }
        do {
            let results: [RemoteAttraction] = try await client
                .from("places_attraction")
                .select("*, cities(name_zh, name_en, countries(code))")
                .eq("id", value: remoteID.uuidString)
                .limit(1)
                .execute()
                .value

            guard let remote = results.first else { return false }

            attraction.nameEN = remote.nameEN
            attraction.nameZH = remote.nameZH ?? ""
            attraction.nameLocal = remote.nameLocal ?? ""
            attraction.address = remote.address ?? ""
            attraction.phone = remote.phone ?? ""
            attraction.ticketPrice = remote.ticketPrice ?? ""
            attraction.openingHours = remote.openingHours ?? ""
            attraction.photographyRules = remote.photographyRules ?? ""
            attraction.allowedItems = remote.allowedItems ?? ""
            attraction.notes = remote.notes ?? ""
            attraction.updatedAt = remote.updatedAt
            attraction.needsSync = false
            try? context.save()

            deleteLocalPhotos(for: attraction.id, context: context)
            try? context.save()
            await downloadPhotosForPlace(placeID: attraction.id, placeRemoteID: remoteID, placeType: "attraction", context: context)
            try? context.save()
            return true
        } catch {
            print("景點更新本地失敗：\(error)")
            return false
        }
    }

    // MARK: - 更新本地全部（批次從雲端拉最新覆蓋所有本機已有的地點）

    func refreshAllLocalPlaces(context: ModelContext) async -> RefreshResult {
        var refreshed = 0
        var failed = 0

        let hotelDescriptor = FetchDescriptor<PlaceHotel>(
            predicate: #Predicate { $0.remoteID != nil }
        )
        if let hotels = try? context.fetch(hotelDescriptor) {
            for hotel in hotels {
                if await refreshLocalHotel(hotel, context: context) {
                    refreshed += 1
                } else {
                    failed += 1
                }
            }
        }

        let restaurantDescriptor = FetchDescriptor<PlaceRestaurant>(
            predicate: #Predicate { $0.remoteID != nil }
        )
        if let restaurants = try? context.fetch(restaurantDescriptor) {
            for restaurant in restaurants {
                if await refreshLocalRestaurant(restaurant, context: context) {
                    refreshed += 1
                } else {
                    failed += 1
                }
            }
        }

        let attractionDescriptor = FetchDescriptor<PlaceAttraction>(
            predicate: #Predicate { $0.remoteID != nil }
        )
        if let attractions = try? context.fetch(attractionDescriptor) {
            for attraction in attractions {
                if await refreshLocalAttraction(attraction, context: context) {
                    refreshed += 1
                } else {
                    failed += 1
                }
            }
        }

        return RefreshResult(refreshed: refreshed, failed: failed)
    }

    // MARK: - Extension 內部輔助方法

    private func findOrCreateCityInExtension(nameZH: String, nameEN: String, countryCode: String, remoteID: UUID, context: ModelContext) -> City? {
        let byRemoteID = FetchDescriptor<City>(predicate: #Predicate { $0.remoteID == remoteID })
        if let city = try? context.fetch(byRemoteID).first { return city }

        let byCode = FetchDescriptor<Country>(predicate: #Predicate { $0.code == countryCode })
        guard let country = try? context.fetch(byCode).first else { return nil }

        let byName = FetchDescriptor<City>(predicate: #Predicate { $0.nameEN == nameEN && $0.country?.code == countryCode })
        if let city = try? context.fetch(byName).first {
            city.remoteID = remoteID
            return city
        }

        let newCity = City(nameZH: nameZH, nameEN: nameEN, country: country)
        newCity.remoteID = remoteID
        context.insert(newCity)
        return newCity
    }

    private func jsonStringFromAnyCodable(_ anyCodable: AnyCodable?) -> String {
        guard let anyCodable,
              let data = try? JSONSerialization.data(withJSONObject: anyCodable.value),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}

// MARK: - 結果類型

struct RefreshResult {
    var refreshed: Int = 0
    var failed: Int = 0

    var summary: String {
        if failed == 0 {
            return refreshed == 0 ? "本機資料已是最新" : "已更新 \(refreshed) 筆本機資料"
        } else {
            return "更新完成：\(refreshed) 筆成功，\(failed) 筆失敗"
        }
    }
}

// MARK: - 雲端預覽用輕量 Decodable

struct RemoteHotelPreview: Codable {
    let id: UUID
    let nameEN: String
    let nameZH: String?
    let updatedAt: Date
    let cities: RemoteCityRef

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case updatedAt = "updated_at"
        case cities
    }
}

struct RemoteRestaurantPreview: Codable {
    let id: UUID
    let nameEN: String
    let nameZH: String?
    let updatedAt: Date
    let cities: RemoteCityRef

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case updatedAt = "updated_at"
        case cities
    }
}

struct RemoteAttractionPreview: Codable {
    let id: UUID
    let nameEN: String
    let nameZH: String?
    let updatedAt: Date
    let cities: RemoteCityRef

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case updatedAt = "updated_at"
        case cities
    }
}
