import Foundation
import Supabase
import SwiftData

@MainActor
class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let info = Bundle.main.infoDictionary
        guard
            let urlString = info?["SUPABASE_URL"] as? String,
            let url = URL(string: urlString),
            let key = info?["SUPABASE_ANON_KEY"] as? String
        else {
            fatalError("SupabaseManager：Info.plist 缺少 SUPABASE_URL 或 SUPABASE_ANON_KEY，請確認 xcconfig 設定正確")
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    // MARK: - 連線測試

    func testConnection() async -> Bool {
        do {
            let _: [AnyJSON] = try await client
                .from("countries")
                .select("id")
                .limit(1)
                .execute()
                .value
            return true
        } catch {
            print("Supabase 連線失敗：\(error)")
            return false
        }
    }

    // MARK: - 國家城市同步（進入地點庫時自動觸發，全量下載）

    func syncCountriesAndCities(context: ModelContext) async {
        await syncCities(context: context)
        await uploadLocalCities(context: context)
    }

    private func syncCities(context: ModelContext) async {
        do {
            let remoteCities: [RemoteCity] = try await client
                .from("cities")
                .select("id, name_zh, name_en, is_preset, countries(code)")
                .execute()
                .value

            for remoteCity in remoteCities {
                let countryCode = remoteCity.countries.code
                let countryDescriptor = FetchDescriptor<Country>(
                    predicate: #Predicate { $0.code == countryCode }
                )
                guard let country = try? context.fetch(countryDescriptor).first else { continue }

                let remoteUUID = remoteCity.id
                let cityByRemoteID = FetchDescriptor<City>(
                    predicate: #Predicate { $0.remoteID == remoteUUID }
                )

                if let existingCity = try? context.fetch(cityByRemoteID).first {
                    existingCity.nameZH = remoteCity.nameZH
                    existingCity.nameEN = remoteCity.nameEN
                    existingCity.isPreset = remoteCity.isPreset
                } else {
                    let nameEN = remoteCity.nameEN
                    let cityByName = FetchDescriptor<City>(
                        predicate: #Predicate { $0.nameEN == nameEN && $0.country?.code == countryCode }
                    )
                    if let localCity = try? context.fetch(cityByName).first {
                        localCity.remoteID = remoteCity.id
                        localCity.isPreset = remoteCity.isPreset
                    } else {
                        let newCity = City(
                            nameZH: remoteCity.nameZH,
                            nameEN: remoteCity.nameEN,
                            country: country,
                            isPreset: remoteCity.isPreset
                        )
                        newCity.remoteID = remoteCity.id
                        context.insert(newCity)
                    }
                }
            }

            try? context.save()
            print("城市同步完成，共 \(remoteCities.count) 筆")
        } catch {
            print("城市同步失敗：\(error)")
        }
    }

    func uploadLocalCities(context: ModelContext) async {
        let descriptor = FetchDescriptor<City>(
            predicate: #Predicate { $0.remoteID == nil }
        )
        guard let localCities = try? context.fetch(descriptor), !localCities.isEmpty else {
            print("沒有待上傳的城市")
            return
        }

        for city in localCities {
            guard let countryCode = city.country?.code else { continue }

            let countryResponse: [RemoteIDResponse] = (try? await client
                .from("countries")
                .select("id")
                .eq("code", value: countryCode)
                .limit(1)
                .execute()
                .value) ?? []

            guard let countryRemoteID = countryResponse.first?.id else {
                print("城市「\(city.nameEN)」找不到對應的雲端國家（\(countryCode)），略過")
                continue
            }

            let payload = CityPayload(
                nameZH: city.nameZH,
                nameEN: city.nameEN,
                countryID: countryRemoteID
            )

            do {
                let response: [RemoteIDResponse] = try await client
                    .from("cities")
                    .upsert(payload, onConflict: "name_en,country_id")
                    .select("id")
                    .execute()
                    .value

                if let remoteID = response.first?.id {
                    city.remoteID = remoteID
                    print("城市上傳成功：\(city.nameEN)（\(remoteID)）")
                }
            } catch {
                print("城市上傳失敗「\(city.nameEN)」：\(error)")
            }
        }

        try? context.save()
    }

    // MARK: - 上傳待同步地點（批次，手動觸發，含照片）

    func uploadPendingPlaces(context: ModelContext) async -> SyncResult {
        var result = SyncResult()

        // 1. 上傳地點資料有異動的（needsSync = true），同時同步照片
        let hotelDescriptor = FetchDescriptor<PlaceHotel>(
            predicate: #Predicate { $0.needsSync == true }
        )
        if let hotels = try? context.fetch(hotelDescriptor) {
            for hotel in hotels {
                if await uploadHotel(hotel, context: context) {
                    result.uploaded += 1
                    if let remoteID = hotel.remoteID {
                        let pr = await syncPhotos(for: hotel.id, placeType: "hotel", remoteID: remoteID, context: context)
                        result.photosUploaded += pr.uploaded
                        result.photosDeleted += pr.deleted
                        result.photosFailed += pr.failed
                    }
                } else {
                    result.failed += 1
                }
            }
        }

        let restaurantDescriptor = FetchDescriptor<PlaceRestaurant>(
            predicate: #Predicate { $0.needsSync == true }
        )
        if let restaurants = try? context.fetch(restaurantDescriptor) {
            for restaurant in restaurants {
                if await uploadRestaurant(restaurant, context: context) {
                    result.uploaded += 1
                    if let remoteID = restaurant.remoteID {
                        let pr = await syncPhotos(for: restaurant.id, placeType: "restaurant", remoteID: remoteID, context: context)
                        result.photosUploaded += pr.uploaded
                        result.photosDeleted += pr.deleted
                        result.photosFailed += pr.failed
                    }
                } else {
                    result.failed += 1
                }
            }
        }

        let attractionDescriptor = FetchDescriptor<PlaceAttraction>(
            predicate: #Predicate { $0.needsSync == true }
        )
        if let attractions = try? context.fetch(attractionDescriptor) {
            for attraction in attractions {
                if await uploadAttraction(attraction, context: context) {
                    result.uploaded += 1
                    if let remoteID = attraction.remoteID {
                        let pr = await syncPhotos(for: attraction.id, placeType: "attraction", remoteID: remoteID, context: context)
                        result.photosUploaded += pr.uploaded
                        result.photosDeleted += pr.deleted
                        result.photosFailed += pr.failed
                    }
                } else {
                    result.failed += 1
                }
            }
        }

        // 2. 處理只有照片異動（地點資料不需更新）的地點
        let photoDescriptor = FetchDescriptor<PlacePhoto>(
            predicate: #Predicate { $0.needsUpload == true || $0.needsDelete == true }
        )
        if let pendingPhotos = try? context.fetch(photoDescriptor) {
            let placeIDs = Set(pendingPhotos.map { $0.placeID })
            for placeID in placeIDs {
                let hotelPred = FetchDescriptor<PlaceHotel>(predicate: #Predicate { $0.id == placeID })
                let restPred = FetchDescriptor<PlaceRestaurant>(predicate: #Predicate { $0.id == placeID })
                let attrPred = FetchDescriptor<PlaceAttraction>(predicate: #Predicate { $0.id == placeID })

                if let hotel = (try? context.fetch(hotelPred))?.first,
                   !hotel.needsSync,
                   let remoteID = hotel.remoteID {
                    let pr = await syncPhotos(for: placeID, placeType: "hotel", remoteID: remoteID, context: context)
                    result.photosUploaded += pr.uploaded
                    result.photosDeleted += pr.deleted
                    result.photosFailed += pr.failed
                } else if let restaurant = (try? context.fetch(restPred))?.first,
                          !restaurant.needsSync,
                          let remoteID = restaurant.remoteID {
                    let pr = await syncPhotos(for: placeID, placeType: "restaurant", remoteID: remoteID, context: context)
                    result.photosUploaded += pr.uploaded
                    result.photosDeleted += pr.deleted
                    result.photosFailed += pr.failed
                } else if let attraction = (try? context.fetch(attrPred))?.first,
                          !attraction.needsSync,
                          let remoteID = attraction.remoteID {
                    let pr = await syncPhotos(for: placeID, placeType: "attraction", remoteID: remoteID, context: context)
                    result.photosUploaded += pr.uploaded
                    result.photosDeleted += pr.deleted
                    result.photosFailed += pr.failed
                }
            }
        }

        try? context.save()
        return result
    }

    // MARK: - 上傳單筆地點（供詳細頁和批次同步呼叫）

    func uploadHotel(_ hotel: PlaceHotel, context: ModelContext) async -> Bool {
        guard let cityRemoteID = hotel.city?.remoteID else {
            print("飯店「\(hotel.nameEN)」的城市尚未同步，略過")
            return false
        }

        let payload = HotelPayload(
            id: hotel.remoteID,
            nameEN: hotel.nameEN,
            nameENNormalized: hotel.nameEN.trimmingCharacters(in: .whitespaces).lowercased(),
            nameZH: hotel.nameZH.isEmpty ? nil : hotel.nameZH,
            nameLocal: nil,
            cityID: cityRemoteID,
            address: hotel.address.isEmpty ? nil : hotel.address,
            phone: hotel.phone.isEmpty ? nil : hotel.phone,
            floorsAndHours: jsonStringToAnyCodable(hotel.floorsAndHoursData),
            wifi: jsonStringToAnyCodable(hotel.wifiData),
            phoneDialing: jsonStringToAnyCodable(hotel.phoneDialingData),
            amenitiesAndFacilities: jsonStringToAnyCodable(hotel.amenitiesData),
            surroundingsAndNotes: hotel.surroundingsAndNotes.isEmpty ? nil : hotel.surroundingsAndNotes,
            updatedAt: hotel.updatedAt
        )

        do {
            let response: [RemoteIDResponse] = try await client
                .from("places_hotel")
                .upsert(payload, onConflict: "name_en,city_id")
                .select("id")
                .execute()
                .value

            if let remoteID = response.first?.id {
                hotel.remoteID = remoteID
                hotel.needsSync = false
            }
            return true
        } catch {
            print("飯店上傳失敗「\(hotel.nameEN)」：\(error)")
            return false
        }
    }

    func uploadRestaurant(_ restaurant: PlaceRestaurant, context: ModelContext) async -> Bool {
        guard let cityRemoteID = restaurant.city?.remoteID else {
            print("餐廳「\(restaurant.nameEN)」的城市尚未同步，略過")
            return false
        }

        let payload = RestaurantPayload(
            id: restaurant.remoteID,
            nameEN: restaurant.nameEN,
            nameENNormalized: restaurant.nameEN.trimmingCharacters(in: .whitespaces).lowercased(),
            nameZH: restaurant.nameZH.isEmpty ? nil : restaurant.nameZH,
            nameLocal: restaurant.nameLocal.isEmpty ? nil : restaurant.nameLocal,
            cityID: cityRemoteID,
            address: restaurant.address.isEmpty ? nil : restaurant.address,
            phone: restaurant.phone.isEmpty ? nil : restaurant.phone,
            cuisine: restaurant.cuisine.isEmpty ? nil : restaurant.cuisine,
            rating: restaurant.rating.isEmpty ? nil : restaurant.rating,
            specialty: restaurant.specialty.isEmpty ? nil : restaurant.specialty,
            notes: restaurant.notes.isEmpty ? nil : restaurant.notes,
            updatedAt: restaurant.updatedAt
        )

        do {
            let response: [RemoteIDResponse] = try await client
                .from("places_restaurant")
                .upsert(payload, onConflict: "name_en,city_id")
                .select("id")
                .execute()
                .value

            if let remoteID = response.first?.id {
                restaurant.remoteID = remoteID
                restaurant.needsSync = false
            }
            return true
        } catch {
            print("餐廳上傳失敗「\(restaurant.nameEN)」：\(error)")
            return false
        }
    }

    func uploadAttraction(_ attraction: PlaceAttraction, context: ModelContext) async -> Bool {
        guard let cityRemoteID = attraction.city?.remoteID else {
            print("景點「\(attraction.nameEN)」的城市尚未同步，略過")
            return false
        }

        let payload = AttractionPayload(
            id: attraction.remoteID,
            nameEN: attraction.nameEN,
            nameENNormalized: attraction.nameEN.trimmingCharacters(in: .whitespaces).lowercased(),
            nameZH: attraction.nameZH.isEmpty ? nil : attraction.nameZH,
            nameLocal: attraction.nameLocal.isEmpty ? nil : attraction.nameLocal,
            cityID: cityRemoteID,
            address: attraction.address.isEmpty ? nil : attraction.address,
            phone: attraction.phone.isEmpty ? nil : attraction.phone,
            ticketPrice: attraction.ticketPrice.isEmpty ? nil : attraction.ticketPrice,
            openingHours: attraction.openingHours.isEmpty ? nil : attraction.openingHours,
            photographyRules: attraction.photographyRules.isEmpty ? nil : attraction.photographyRules,
            allowedItems: attraction.allowedItems.isEmpty ? nil : attraction.allowedItems,
            notes: attraction.notes.isEmpty ? nil : attraction.notes,
            updatedAt: attraction.updatedAt
        )

        do {
            let response: [RemoteIDResponse] = try await client
                .from("places_attraction")
                .upsert(payload, onConflict: "name_en,city_id")
                .select("id")
                .execute()
                .value

            if let remoteID = response.first?.id {
                attraction.remoteID = remoteID
                attraction.needsSync = false
            }
            return true
        } catch {
            print("景點上傳失敗「\(attraction.nameEN)」：\(error)")
            return false
        }
    }

    // MARK: - 搜尋雲端地點（按下搜尋鍵觸發，合併進本機）

    func searchRemotePlaces(query: String, context: ModelContext) async -> SearchResult {
        let normalized = query.trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return SearchResult() }

        async let hotelsCount = searchRemoteHotels(query: normalized, context: context)
        async let restaurantsCount = searchRemoteRestaurants(query: normalized, context: context)
        async let attractionsCount = searchRemoteAttractions(query: normalized, context: context)

        let result = SearchResult(
            newHotels: await hotelsCount,
            newRestaurants: await restaurantsCount,
            newAttractions: await attractionsCount
        )

        try? context.save()
        return result
    }

    private func searchRemoteHotels(query: String, context: ModelContext) async -> Int {
        do {
            let remoteHotels: [RemoteHotel] = try await client
                .from("places_hotel")
                .select("*, cities(name_zh, name_en, countries(code))")
                .or("name_en.ilike.%\(query)%,name_zh.ilike.%\(query)%")
                .execute()
                .value
            return remoteHotels.reduce(0) { $0 + (mergeHotel($1, context: context) ? 1 : 0) }
        } catch {
            print("飯店雲端搜尋失敗：\(error)")
            return 0
        }
    }

    private func searchRemoteRestaurants(query: String, context: ModelContext) async -> Int {
        do {
            let remoteRestaurants: [RemoteRestaurant] = try await client
                .from("places_restaurant")
                .select("*, cities(name_zh, name_en, countries(code))")
                .or("name_en.ilike.%\(query)%,name_zh.ilike.%\(query)%")
                .execute()
                .value
            return remoteRestaurants.reduce(0) { $0 + (mergeRestaurant($1, context: context) ? 1 : 0) }
        } catch {
            print("餐廳雲端搜尋失敗：\(error)")
            return 0
        }
    }

    private func searchRemoteAttractions(query: String, context: ModelContext) async -> Int {
        do {
            let remoteAttractions: [RemoteAttraction] = try await client
                .from("places_attraction")
                .select("*, cities(name_zh, name_en, countries(code))")
                .or("name_en.ilike.%\(query)%,name_zh.ilike.%\(query)%")
                .execute()
                .value
            return remoteAttractions.reduce(0) { $0 + (mergeAttraction($1, context: context) ? 1 : 0) }
        } catch {
            print("景點雲端搜尋失敗：\(error)")
            return 0
        }
    }

    // MARK: - 合併邏輯（needsSync = false 才覆蓋，本機優先）

    @discardableResult
    private func mergeHotel(_ remote: RemoteHotel, context: ModelContext) -> Bool {
        let remoteUUID = remote.id
        let descriptor = FetchDescriptor<PlaceHotel>(predicate: #Predicate { $0.remoteID == remoteUUID })
        if let local = try? context.fetch(descriptor).first {
            if local.needsSync { return false }
            if remote.updatedAt > local.updatedAt {
                local.nameEN = remote.nameEN
                local.nameZH = remote.nameZH ?? ""
                local.address = remote.address ?? ""
                local.phone = remote.phone ?? ""
                local.floorsAndHoursData = anyCodableToJsonString(remote.floorsAndHours)
                local.wifiData = anyCodableToJsonString(remote.wifi)
                local.phoneDialingData = anyCodableToJsonString(remote.phoneDialing)
                local.amenitiesData = anyCodableToJsonString(remote.amenitiesAndFacilities)
                local.surroundingsAndNotes = remote.surroundingsAndNotes ?? ""
                local.updatedAt = remote.updatedAt
            }
            return false
        } else {
            let city = findOrCreateCity(nameZH: remote.cities.nameZH, nameEN: remote.cities.nameEN, countryCode: remote.cities.countries.code, remoteID: remote.cityID, context: context)
            let hotel = PlaceHotel(nameEN: remote.nameEN, city: city)
            hotel.remoteID = remote.id
            hotel.nameZH = remote.nameZH ?? ""
            hotel.address = remote.address ?? ""
            hotel.phone = remote.phone ?? ""
            hotel.floorsAndHoursData = anyCodableToJsonString(remote.floorsAndHours)
            hotel.wifiData = anyCodableToJsonString(remote.wifi)
            hotel.phoneDialingData = anyCodableToJsonString(remote.phoneDialing)
            hotel.amenitiesData = anyCodableToJsonString(remote.amenitiesAndFacilities)
            hotel.surroundingsAndNotes = remote.surroundingsAndNotes ?? ""
            hotel.updatedAt = remote.updatedAt
            hotel.needsSync = false
            context.insert(hotel)
            return true
        }
    }

    @discardableResult
    private func mergeRestaurant(_ remote: RemoteRestaurant, context: ModelContext) -> Bool {
        let remoteUUID = remote.id
        let descriptor = FetchDescriptor<PlaceRestaurant>(predicate: #Predicate { $0.remoteID == remoteUUID })
        if let local = try? context.fetch(descriptor).first {
            if local.needsSync { return false }
            if remote.updatedAt > local.updatedAt {
                local.nameEN = remote.nameEN
                local.nameZH = remote.nameZH ?? ""
                local.nameLocal = remote.nameLocal ?? ""
                local.address = remote.address ?? ""
                local.phone = remote.phone ?? ""
                local.cuisine = remote.cuisine ?? ""
                local.rating = remote.rating ?? ""
                local.specialty = remote.specialty ?? ""
                local.notes = remote.notes ?? ""
                local.updatedAt = remote.updatedAt
            }
            return false
        } else {
            let city = findOrCreateCity(nameZH: remote.cities.nameZH, nameEN: remote.cities.nameEN, countryCode: remote.cities.countries.code, remoteID: remote.cityID, context: context)
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
            return true
        }
    }

    @discardableResult
    private func mergeAttraction(_ remote: RemoteAttraction, context: ModelContext) -> Bool {
        let remoteUUID = remote.id
        let descriptor = FetchDescriptor<PlaceAttraction>(predicate: #Predicate { $0.remoteID == remoteUUID })
        if let local = try? context.fetch(descriptor).first {
            if local.needsSync { return false }
            if remote.updatedAt > local.updatedAt {
                local.nameEN = remote.nameEN
                local.nameZH = remote.nameZH ?? ""
                local.nameLocal = remote.nameLocal ?? ""
                local.address = remote.address ?? ""
                local.phone = remote.phone ?? ""
                local.ticketPrice = remote.ticketPrice ?? ""
                local.openingHours = remote.openingHours ?? ""
                local.photographyRules = remote.photographyRules ?? ""
                local.allowedItems = remote.allowedItems ?? ""
                local.notes = remote.notes ?? ""
                local.updatedAt = remote.updatedAt
            }
            return false
        } else {
            let city = findOrCreateCity(nameZH: remote.cities.nameZH, nameEN: remote.cities.nameEN, countryCode: remote.cities.countries.code, remoteID: remote.cityID, context: context)
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
            return true
        }
    }

    // MARK: - 輔助：找到或建立本機城市

    private func findOrCreateCity(nameZH: String, nameEN: String, countryCode: String, remoteID: UUID, context: ModelContext) -> City? {
        let descriptor = FetchDescriptor<City>(predicate: #Predicate { $0.remoteID == remoteID })
        if let city = try? context.fetch(descriptor).first { return city }

        let countryDescriptor = FetchDescriptor<Country>(predicate: #Predicate { $0.code == countryCode })
        guard let country = try? context.fetch(countryDescriptor).first else { return nil }

        let nameDescriptor = FetchDescriptor<City>(predicate: #Predicate { $0.nameEN == nameEN && $0.country?.code == countryCode })
        if let city = try? context.fetch(nameDescriptor).first {
            city.remoteID = remoteID
            return city
        }

        let newCity = City(nameZH: nameZH, nameEN: nameEN, country: country)
        newCity.remoteID = remoteID
        context.insert(newCity)
        return newCity
    }

    // MARK: - 輔助：JSON String 轉 AnyCodable

    private func jsonStringToAnyCodable(_ jsonString: String) -> AnyCodable? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return AnyCodable(obj)
    }

    private func anyCodableToJsonString(_ anyCodable: AnyCodable?) -> String {
        guard let anyCodable,
              let data = try? JSONSerialization.data(withJSONObject: anyCodable.value),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}

// MARK: - 結果類型

struct SyncResult {
    var uploaded: Int = 0
    var failed: Int = 0
    var photosUploaded: Int = 0
    var photosDeleted: Int = 0
    var photosFailed: Int = 0

    var hasFailures: Bool { failed > 0 || photosFailed > 0 }
    var summary: String {
        var parts: [String] = []
        if uploaded > 0 { parts.append("地點 \(uploaded) 筆") }
        if photosUploaded > 0 { parts.append("照片上傳 \(photosUploaded) 張") }
        if photosDeleted > 0 { parts.append("照片刪除 \(photosDeleted) 張") }
        if parts.isEmpty && failed == 0 && photosFailed == 0 {
            return "沒有待上傳的資料"
        }
        var result = parts.isEmpty ? "" : "已同步：" + parts.joined(separator: "、")
        if failed > 0 { result += "（\(failed) 筆地點失敗）" }
        if photosFailed > 0 { result += "（\(photosFailed) 張照片失敗）" }
        return result
    }
}

struct SearchResult {
    var newHotels: Int = 0
    var newRestaurants: Int = 0
    var newAttractions: Int = 0

    var totalNew: Int { newHotels + newRestaurants + newAttractions }
    var hasNewData: Bool { totalNew > 0 }
    var summary: String {
        guard hasNewData else { return "沒有新的雲端資料" }
        var parts: [String] = []
        if newHotels > 0 { parts.append("飯店 \(newHotels) 筆") }
        if newRestaurants > 0 { parts.append("餐廳 \(newRestaurants) 筆") }
        if newAttractions > 0 { parts.append("景點 \(newAttractions) 筆") }
        return "新增：" + parts.joined(separator: "、")
    }
}

// MARK: - Supabase 資料結構（Decodable，對應雲端回傳）

struct RemoteCity: Codable {
    let id: UUID
    let nameZH: String
    let nameEN: String
    let isPreset: Bool
    let countries: RemoteCountryRef

    enum CodingKeys: String, CodingKey {
        case id
        case nameZH = "name_zh"
        case nameEN = "name_en"
        case isPreset = "is_preset"
        case countries
    }
}

struct RemoteCountryRef: Codable {
    let code: String
}

struct RemoteCityRef: Codable {
    let nameZH: String
    let nameEN: String
    let countries: RemoteCountryRef

    enum CodingKeys: String, CodingKey {
        case nameZH = "name_zh"
        case nameEN = "name_en"
        case countries
    }
}

struct RemoteIDResponse: Codable {
    let id: UUID
}

struct RemoteHotel: Codable {
    let id: UUID
    let nameEN: String
    let nameZH: String?
    let cityID: UUID
    let address: String?
    let phone: String?
    let floorsAndHours: AnyCodable?
    let wifi: AnyCodable?
    let phoneDialing: AnyCodable?
    let amenitiesAndFacilities: AnyCodable?
    let surroundingsAndNotes: String?
    let updatedAt: Date
    let cities: RemoteCityRef

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case cityID = "city_id"
        case address, phone
        case floorsAndHours = "floors_and_hours"
        case wifi
        case phoneDialing = "phone_dialing"
        case amenitiesAndFacilities = "amenities_and_facilities"
        case surroundingsAndNotes = "surroundings_and_notes"
        case updatedAt = "updated_at"
        case cities
    }
}

struct RemoteRestaurant: Codable {
    let id: UUID
    let nameEN: String
    let nameZH: String?
    let nameLocal: String?
    let cityID: UUID
    let address: String?
    let phone: String?
    let cuisine: String?
    let rating: String?
    let specialty: String?
    let notes: String?
    let updatedAt: Date
    let cities: RemoteCityRef

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case nameLocal = "name_local"
        case cityID = "city_id"
        case address, phone, cuisine, rating, specialty, notes
        case updatedAt = "updated_at"
        case cities
    }
}

struct RemoteAttraction: Codable {
    let id: UUID
    let nameEN: String
    let nameZH: String?
    let nameLocal: String?
    let cityID: UUID
    let address: String?
    let phone: String?
    let ticketPrice: String?
    let openingHours: String?
    let photographyRules: String?
    let allowedItems: String?
    let notes: String?
    let updatedAt: Date
    let cities: RemoteCityRef

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameZH = "name_zh"
        case nameLocal = "name_local"
        case cityID = "city_id"
        case address, phone
        case ticketPrice = "ticket_price"
        case openingHours = "opening_hours"
        case photographyRules = "photography_rules"
        case allowedItems = "allowed_items"
        case notes
        case updatedAt = "updated_at"
        case cities
    }
}

// MARK: - Upload Payloads（上傳用，Encodable，snake_case 對應 Supabase 欄位）

struct CityPayload: Encodable {
    let nameZH: String
    let nameEN: String
    let countryID: UUID

    enum CodingKeys: String, CodingKey {
        case nameZH = "name_zh"
        case nameEN = "name_en"
        case countryID = "country_id"
    }
}

struct HotelPayload: Encodable {
    let id: UUID?
    let nameEN: String
    let nameENNormalized: String
    let nameZH: String?
    let nameLocal: String?
    let cityID: UUID
    let address: String?
    let phone: String?
    let floorsAndHours: AnyCodable?
    let wifi: AnyCodable?
    let phoneDialing: AnyCodable?
    let amenitiesAndFacilities: AnyCodable?
    let surroundingsAndNotes: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameENNormalized = "name_en_normalized"
        case nameZH = "name_zh"
        case nameLocal = "name_local"
        case cityID = "city_id"
        case address, phone
        case floorsAndHours = "floors_and_hours"
        case wifi
        case phoneDialing = "phone_dialing"
        case amenitiesAndFacilities = "amenities_and_facilities"
        case surroundingsAndNotes = "surroundings_and_notes"
        case updatedAt = "updated_at"
    }
}

struct RestaurantPayload: Encodable {
    let id: UUID?
    let nameEN: String
    let nameENNormalized: String
    let nameZH: String?
    let nameLocal: String?
    let cityID: UUID
    let address: String?
    let phone: String?
    let cuisine: String?
    let rating: String?
    let specialty: String?
    let notes: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameENNormalized = "name_en_normalized"
        case nameZH = "name_zh"
        case nameLocal = "name_local"
        case cityID = "city_id"
        case address, phone, cuisine, rating, specialty, notes
        case updatedAt = "updated_at"
    }
}

struct AttractionPayload: Encodable {
    let id: UUID?
    let nameEN: String
    let nameENNormalized: String
    let nameZH: String?
    let nameLocal: String?
    let cityID: UUID
    let address: String?
    let phone: String?
    let ticketPrice: String?
    let openingHours: String?
    let photographyRules: String?
    let allowedItems: String?
    let notes: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameENNormalized = "name_en_normalized"
        case nameZH = "name_zh"
        case nameLocal = "name_local"
        case cityID = "city_id"
        case address, phone
        case ticketPrice = "ticket_price"
        case openingHours = "opening_hours"
        case photographyRules = "photography_rules"
        case allowedItems = "allowed_items"
        case notes
        case updatedAt = "updated_at"
    }
}

// MARK: - AnyCodable（用於 JSONB 欄位）

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        default:
            try container.encodeNil()
        }
    }
}
