import Foundation
import SwiftData
import UIKit

// MARK: - 備份元資料

struct BackupMeta: Codable {
    let createdAt: Date
    let appVersion: String
    let deviceModel: String
    let teamCount: Int
    let expenseCount: Int
    let journalCount: Int
    let customTypeCount: Int
    let cityCount: Int
    let placeCount: Int
    let photoCount: Int
    let photoSizeBytes: Int
}

// MARK: - 各 Model 備份結構

struct TeamBackup: Codable {
    let id: String
    let tourCode: String
    let name: String
    let departureDate: Date
    let days: Int
    let paxCount: Int?
    let roomCount: String?
    let status: String
    let countryCodesData: String
    let notes: String?
    let createdAt: Date
}

struct ExpenseBackup: Codable {
    let id: String
    let teamID: String
    let date: Date
    let location: String?
    let item: String
    let quantity: String
    let amount: String
    let currency: String
    let exchangeRate: String
    let convertedAmount: String
    let receiptNumber: String?
    let paymentMethod: String?
    let notes: String?
    let createdAt: Date
}

struct IncomeBackup: Codable {
    let id: String
    let teamID: String
    let date: Date
    let typeName: String
    let amount: String
    let currency: String
    let notes: String?
    let createdAt: Date
}

struct TourFundBackup: Codable {
    let id: String
    let teamID: String
    let typeName: String
    let currency: String
    let initialAmount: String
    let isReimbursable: Bool
    let notes: String?
}

struct JournalBackup: Codable {
    let id: String
    let teamID: String
    let date: Date
    let content: String
    let createdAt: Date
    let updatedAt: Date
}

struct CustomFundTypeBackup: Codable {
    let id: String
    let name: String
    let iconName: String
    let sortOrder: Int
    let createdAt: Date
}

struct CustomIncomeTypeBackup: Codable {
    let id: String
    let name: String
    let iconName: String
    let sortOrder: Int
    let createdAt: Date
}

struct CityBackup: Codable {
    let id: String
    let nameZH: String
    let nameEN: String
    let countryCode: String    // Country.isoCode，還原時重新關聯
    let remoteID: String?
    let createdAt: Date
}

struct PlaceHotelBackup: Codable {
    let id: String
    let nameEN: String
    let nameZH: String
    let cityID: String?        // 對應 CityBackup.id
    let address: String
    let phone: String
    let floorsAndHoursData: String
    let wifiData: String
    let phoneDialingData: String
    let amenitiesData: String
    let surroundingsAndNotes: String
    let createdAt: Date
    let updatedAt: Date
}

struct PlaceRestaurantBackup: Codable {
    let id: String
    let nameEN: String
    let nameZH: String
    let nameLocal: String
    let cityID: String?
    let address: String
    let phone: String
    let cuisine: String
    let rating: String
    let specialty: String
    let notes: String
    let createdAt: Date
    let updatedAt: Date
}

struct PlaceAttractionBackup: Codable {
    let id: String
    let nameEN: String
    let nameZH: String
    let nameLocal: String
    let cityID: String?
    let address: String
    let phone: String
    let ticketPrice: String
    let openingHours: String
    let photographyRules: String
    let allowedItems: String
    let notes: String
    let createdAt: Date
    let updatedAt: Date
}

struct PlacePhotoBackup: Codable {
    let id: String
    let placeID: String
    let fileName: String
    let category: String
    let sortOrder: Int
    let createdAt: Date
    let imageData: String      // base64 編碼的照片資料
}

struct ProfileBackup: Codable {
    let nameZH: String
    let nameEN: String
    let phone: String
    let lineID: String
    let notes: String
}

// MARK: - 整體備份容器

struct BackupData: Codable {
    let meta: BackupMeta
    let profile: ProfileBackup?
    let teams: [TeamBackup]
    let expenses: [ExpenseBackup]
    let incomes: [IncomeBackup]
    let tourFunds: [TourFundBackup]
    let journals: [JournalBackup]
    let customFundTypes: [CustomFundTypeBackup]
    let customIncomeTypes: [CustomIncomeTypeBackup]
    let cities: [CityBackup]
    let hotels: [PlaceHotelBackup]
    let restaurants: [PlaceRestaurantBackup]
    let attractions: [PlaceAttractionBackup]
    let photos: [PlacePhotoBackup]
}

// MARK: - 備份檔案資訊（顯示用）

struct BackupFileInfo: Identifiable {
    let id: UUID = UUID()
    let fileName: String
    let fileURL: URL
    let createdAt: Date
    let appVersion: String
    let deviceModel: String
    let teamCount: Int
    let expenseCount: Int
    let journalCount: Int
    let customTypeCount: Int
    let cityCount: Int
    let placeCount: Int
    let photoCount: Int
    let fileSizeBytes: Int

    var fileSizeString: String {
        let mb = Double(fileSizeBytes) / 1_048_576
        if mb < 1 {
            let kb = Double(fileSizeBytes) / 1024
            return String(format: "%.1f KB", kb)
        }
        return String(format: "%.1f MB", mb)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: createdAt)
    }
}

// MARK: - BackupManager

class BackupManager {
    static let shared = BackupManager()
    private init() {}

    private let maxBackupCount = 5
    private let iCloudContainerID = "iCloud.com.TLJStudio.TLABackup"

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - 備份目錄
    // 優先使用 iCloud ubiquity container 根目錄下的 Backups/
    // 放在根目錄（非 Documents/）使用者在「檔案」App 看不到
    // iCloud 不可用時 fallback 到本機 Documents/Backups/
    var backupDirectory: URL {
        let fm = FileManager.default
        if let containerURL = fm.url(forUbiquityContainerIdentifier: iCloudContainerID) {
            let dir = containerURL.appendingPathComponent("Backups", isDirectory: true)
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            return dir
        }
        // fallback：iCloud 不可用
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Backups", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 是否正在使用 iCloud 備份
    var isUsingiCloud: Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerID) != nil
    }

    // MARK: - 建立備份

    func createBackup(context: ModelContext) async throws -> BackupFileInfo {

        // 取得所有資料
        let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let incomes = (try? context.fetch(FetchDescriptor<Income>())) ?? []
        let tourFunds = (try? context.fetch(FetchDescriptor<TourFund>())) ?? []
        let journals = (try? context.fetch(FetchDescriptor<Journal>())) ?? []
        let customFundTypes = (try? context.fetch(FetchDescriptor<CustomFundType>())) ?? []
        let customIncomeTypes = (try? context.fetch(FetchDescriptor<CustomIncomeType>())) ?? []
        let allCities = (try? context.fetch(FetchDescriptor<City>())) ?? []
        let hotels = (try? context.fetch(FetchDescriptor<PlaceHotel>()))?.filter { $0.remoteID == nil } ?? []
        let restaurants = (try? context.fetch(FetchDescriptor<PlaceRestaurant>()))?.filter { $0.remoteID == nil } ?? []
        let attractions = (try? context.fetch(FetchDescriptor<PlaceAttraction>()))?.filter { $0.remoteID == nil } ?? []
        let allPhotos = (try? context.fetch(FetchDescriptor<PlacePhoto>())) ?? []

        // 只備份未上傳雲端的照片
        let pendingPhotos = allPhotos.filter { $0.needsUpload && $0.remoteURL == nil }

        // 序列化照片（含實體檔案 base64）
        var photoBackups: [PlacePhotoBackup] = []
        var totalPhotoBytes = 0
        for photo in pendingPhotos {
            if let data = PlacePhotoManager.shared.loadImageData(fileName: photo.fileName) {
                totalPhotoBytes += data.count
                photoBackups.append(PlacePhotoBackup(
                    id: photo.id.uuidString,
                    placeID: photo.placeID.uuidString,
                    fileName: photo.fileName,
                    category: photo.category,
                    sortOrder: photo.sortOrder,
                    createdAt: photo.createdAt,
                    imageData: data.base64EncodedString()
                ))
            }
        }

        // 組合 meta
        let meta = BackupMeta(
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—",
            deviceModel: UIDevice.current.model,
            teamCount: teams.count,
            expenseCount: expenses.count + incomes.count + tourFunds.count,
            journalCount: journals.count,
            customTypeCount: customFundTypes.count + customIncomeTypes.count,
            cityCount: allCities.count,
            placeCount: hotels.count + restaurants.count + attractions.count,
            photoCount: photoBackups.count,
            photoSizeBytes: totalPhotoBytes
        )

            // 讀取個人資料
            let defaults = UserDefaults.standard
            let profile = ProfileBackup(
                nameZH: defaults.string(forKey: "profile_nameZH") ?? "",
                nameEN: defaults.string(forKey: "profile_nameEN") ?? "",
                phone: defaults.string(forKey: "profile_phone") ?? "",
                lineID: defaults.string(forKey: "profile_lineID") ?? "",
                notes: defaults.string(forKey: "profile_notes") ?? ""
            )

            // 組合備份資料
            let backupData = BackupData(
                meta: meta,
                profile: profile,
            teams: teams.map { TeamBackup(
                id: $0.id.uuidString,
                tourCode: $0.tourCode,
                name: $0.name,
                departureDate: $0.departureDate,
                days: $0.days,
                paxCount: $0.paxCount,
                roomCount: $0.roomCount,
                status: $0.status.rawValue,
                countryCodesData: $0.countryCodesData,
                notes: $0.notes,
                createdAt: $0.createdAt
            )},
            expenses: expenses.map { ExpenseBackup(
                id: $0.id.uuidString,
                teamID: $0.teamID.uuidString,
                date: $0.date,
                location: $0.location,
                item: $0.item,
                quantity: $0.quantity.description,
                amount: $0.amount.description,
                currency: $0.currency,
                exchangeRate: $0.exchangeRate.description,
                convertedAmount: $0.convertedAmount.description,
                receiptNumber: $0.receiptNumber,
                paymentMethod: $0.paymentMethod,
                notes: $0.notes,
                createdAt: $0.createdAt
            )},
            incomes: incomes.map { IncomeBackup(
                id: $0.id.uuidString,
                teamID: $0.teamID.uuidString,
                date: $0.date,
                typeName: $0.typeName,
                amount: $0.amount.description,
                currency: $0.currency,
                notes: $0.notes,
                createdAt: $0.createdAt
            )},
            tourFunds: tourFunds.map { TourFundBackup(
                id: $0.id.uuidString,
                teamID: $0.teamID.uuidString,
                typeName: $0.typeName,
                currency: $0.currency,
                initialAmount: $0.initialAmount.description,
                isReimbursable: $0.isReimbursable,
                notes: $0.notes
            )},
            journals: journals.map { JournalBackup(
                id: $0.id.uuidString,
                teamID: $0.teamID.uuidString,
                date: $0.date,
                content: $0.content,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )},
            customFundTypes: customFundTypes.map { CustomFundTypeBackup(
                id: $0.id.uuidString,
                name: $0.name,
                iconName: $0.iconName,
                sortOrder: $0.sortOrder,
                createdAt: $0.createdAt
            )},
            customIncomeTypes: customIncomeTypes.map { CustomIncomeTypeBackup(
                id: $0.id.uuidString,
                name: $0.name,
                iconName: $0.iconName,
                sortOrder: $0.sortOrder,
                createdAt: $0.createdAt
            )},
            cities: allCities.map { CityBackup(
                id: $0.id.uuidString,
                nameZH: $0.nameZH,
                nameEN: $0.nameEN,
                countryCode: $0.country?.code ?? "",
                remoteID: $0.remoteID?.uuidString,
                createdAt: $0.createdAt
            )},
            hotels: hotels.map { PlaceHotelBackup(
                id: $0.id.uuidString,
                nameEN: $0.nameEN,
                nameZH: $0.nameZH,
                cityID: $0.city?.id.uuidString,
                address: $0.address,
                phone: $0.phone,
                floorsAndHoursData: $0.floorsAndHoursData,
                wifiData: $0.wifiData,
                phoneDialingData: $0.phoneDialingData,
                amenitiesData: $0.amenitiesData,
                surroundingsAndNotes: $0.surroundingsAndNotes,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )},
            restaurants: restaurants.map { PlaceRestaurantBackup(
                id: $0.id.uuidString,
                nameEN: $0.nameEN,
                nameZH: $0.nameZH,
                nameLocal: $0.nameLocal,
                cityID: $0.city?.id.uuidString,
                address: $0.address,
                phone: $0.phone,
                cuisine: $0.cuisine,
                rating: $0.rating,
                specialty: $0.specialty,
                notes: $0.notes,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )},
            attractions: attractions.map { PlaceAttractionBackup(
                id: $0.id.uuidString,
                nameEN: $0.nameEN,
                nameZH: $0.nameZH,
                nameLocal: $0.nameLocal,
                cityID: $0.city?.id.uuidString,
                address: $0.address,
                phone: $0.phone,
                ticketPrice: $0.ticketPrice,
                openingHours: $0.openingHours,
                photographyRules: $0.photographyRules,
                allowedItems: $0.allowedItems,
                notes: $0.notes,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )},
            photos: photoBackups
        )

        // 序列化成 JSON
        let jsonData = try encoder.encode(backupData)

        // 寫入檔案（用 NSFileCoordinator 確保多裝置 iCloud 同步安全）
        let dateStr = DateFormatter.backupFileName.string(from: Date())
        let fileName = "領隊助手備份_\(dateStr).json"
        let fileURL = backupDirectory.appendingPathComponent(fileName)

        var writeError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: nil) { url in
            do {
                try jsonData.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = writeError { throw error }

        // 清理舊備份
        deleteOldBackups()

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0

        return BackupFileInfo(
            fileName: fileName,
            fileURL: fileURL,
            createdAt: meta.createdAt,
            appVersion: meta.appVersion,
            deviceModel: meta.deviceModel,
            teamCount: meta.teamCount,
            expenseCount: meta.expenseCount,
            journalCount: meta.journalCount,
            customTypeCount: meta.customTypeCount,
            cityCount: meta.cityCount,
            placeCount: meta.placeCount,
            photoCount: meta.photoCount,
            fileSizeBytes: fileSize
        )
    }

    // MARK: - 列出備份

    func listBackups() -> [BackupFileInfo] {
        let dir = backupDirectory
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        )) ?? []

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> BackupFileInfo? in
                var result: BackupFileInfo?
                var readError: NSError?
                let coordinator = NSFileCoordinator()
                coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &readError) { coordURL in
                    guard let data = try? Data(contentsOf: coordURL),
                          let backup = try? decoder.decode(BackupData.self, from: data) else { return }
                    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    result = BackupFileInfo(
                        fileName: url.lastPathComponent,
                        fileURL: url,
                        createdAt: backup.meta.createdAt,
                        appVersion: backup.meta.appVersion,
                        deviceModel: backup.meta.deviceModel,
                        teamCount: backup.meta.teamCount,
                        expenseCount: backup.meta.expenseCount,
                        journalCount: backup.meta.journalCount,
                        customTypeCount: backup.meta.customTypeCount,
                        cityCount: backup.meta.cityCount,
                        placeCount: backup.meta.placeCount,
                        photoCount: backup.meta.photoCount,
                        fileSizeBytes: fileSize
                    )
                }
                return result
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - 還原

    func restore(from fileInfo: BackupFileInfo, context: ModelContext) async throws -> RestoreResult {
        let startTime = Date()

        // 用 NSFileCoordinator 讀取（iCloud 安全）
        var jsonData: Data?
        var readError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: fileInfo.fileURL, options: .withoutChanges, error: &readError) { url in
            jsonData = try? Data(contentsOf: url)
        }
        guard let data = jsonData else {
            throw readError ?? NSError(domain: "BackupManager", code: -1,
                                       userInfo: [NSLocalizedDescriptionKey: "無法讀取備份檔案"])
        }
        let backup = try decoder.decode(BackupData.self, from: data)

        // 清除現有資料（保留 Country，從雲端重新下載）
        // City 需逐筆刪除，避免與 Country cascade 關聯衝突
        let cityDesc = FetchDescriptor<City>()
        (try? context.fetch(cityDesc))?.forEach { context.delete($0) }

        try context.delete(model: Team.self)
        try context.delete(model: Expense.self)
        try context.delete(model: Income.self)
        try context.delete(model: TourFund.self)
        try context.delete(model: Journal.self)
        try context.delete(model: CustomFundType.self)
        try context.delete(model: CustomIncomeType.self)
        try context.delete(model: PlaceHotel.self)
        try context.delete(model: PlaceRestaurant.self)
        try context.delete(model: PlaceAttraction.self)
        try context.delete(model: PlacePhoto.self)

        // 清除地點照片實體檔案
        PlacePhotoManager.shared.clearCache()

        // 還原城市（先建立 id → City 對照表供地點使用）
        var cityMap: [String: City] = [:]
        let allCountries = (try? context.fetch(FetchDescriptor<Country>())) ?? []
        for cb in backup.cities {
            if let country = allCountries.first(where: { $0.code == cb.countryCode }) {
                let city = City(nameZH: cb.nameZH, nameEN: cb.nameEN, country: country)
                city.id = UUID(uuidString: cb.id) ?? UUID()
                city.remoteID = cb.remoteID.flatMap { UUID(uuidString: $0) }
                city.createdAt = cb.createdAt
                context.insert(city)
                cityMap[cb.id] = city
            }
        }

        // 還原團體
        for tb in backup.teams {
            let team = Team(
                tourCode: tb.tourCode,
                name: tb.name,
                departureDate: tb.departureDate,
                days: tb.days
            )
            team.id = UUID(uuidString: tb.id) ?? UUID()
            team.paxCount = tb.paxCount
            team.roomCount = tb.roomCount
            team.status = TeamStatus(rawValue: tb.status) ?? .preparing
            team.countryCodesData = tb.countryCodesData
            team.notes = tb.notes
            team.createdAt = tb.createdAt
            context.insert(team)
        }

        // 還原支出
        for eb in backup.expenses {
            guard let teamID = UUID(uuidString: eb.teamID) else { continue }
            let expense = Expense(
                teamID: teamID,
                item: eb.item,
                quantity: Decimal(string: eb.quantity) ?? 0,
                amount: Decimal(string: eb.amount) ?? 0,
                currency: eb.currency,
                exchangeRate: Decimal(string: eb.exchangeRate) ?? 1,
                date: eb.date
            )
            expense.id = UUID(uuidString: eb.id) ?? UUID()
            expense.location = eb.location
            expense.receiptNumber = eb.receiptNumber
            expense.paymentMethod = eb.paymentMethod
            expense.notes = eb.notes
            expense.createdAt = eb.createdAt
            context.insert(expense)
        }

        // 還原收入
        for ib in backup.incomes {
            guard let teamID = UUID(uuidString: ib.teamID) else { continue }
            let income = Income(
                teamID: teamID,
                date: ib.date,
                typeName: ib.typeName,
                amount: Decimal(string: ib.amount) ?? 0,
                currency: ib.currency
            )
            income.id = UUID(uuidString: ib.id) ?? UUID()
            income.notes = ib.notes
            income.createdAt = ib.createdAt
            context.insert(income)
        }

        // 還原資金
        for fb in backup.tourFunds {
            guard let teamID = UUID(uuidString: fb.teamID) else { continue }
            let fund = TourFund(
                teamID: teamID,
                typeName: fb.typeName,
                currency: fb.currency,
                initialAmount: Decimal(string: fb.initialAmount) ?? 0,
                isReimbursable: fb.isReimbursable
            )
            fund.id = UUID(uuidString: fb.id) ?? UUID()
            fund.notes = fb.notes
            context.insert(fund)
        }

        // 還原日誌
        for jb in backup.journals {
            guard let teamID = UUID(uuidString: jb.teamID) else { continue }
            let journal = Journal(teamID: teamID, date: jb.date, content: jb.content)
            journal.id = UUID(uuidString: jb.id) ?? UUID()
            journal.createdAt = jb.createdAt
            journal.updatedAt = jb.updatedAt
            context.insert(journal)
        }

        // 還原自訂類型
        for ft in backup.customFundTypes {
            let fundType = CustomFundType(name: ft.name, iconName: ft.iconName, sortOrder: ft.sortOrder)
            fundType.id = UUID(uuidString: ft.id) ?? UUID()
            fundType.createdAt = ft.createdAt
            context.insert(fundType)
        }
        for it in backup.customIncomeTypes {
            let incomeType = CustomIncomeType(name: it.name, iconName: it.iconName, sortOrder: it.sortOrder)
            incomeType.id = UUID(uuidString: it.id) ?? UUID()
            incomeType.createdAt = it.createdAt
            context.insert(incomeType)
        }

        // 還原本機地點
        for hb in backup.hotels {
            let city = hb.cityID.flatMap { cityMap[$0] }
            let hotel = PlaceHotel(nameEN: hb.nameEN, city: city)
            hotel.id = UUID(uuidString: hb.id) ?? UUID()
            hotel.nameZH = hb.nameZH
            hotel.address = hb.address
            hotel.phone = hb.phone
            hotel.floorsAndHoursData = hb.floorsAndHoursData
            hotel.wifiData = hb.wifiData
            hotel.phoneDialingData = hb.phoneDialingData
            hotel.amenitiesData = hb.amenitiesData
            hotel.surroundingsAndNotes = hb.surroundingsAndNotes
            hotel.createdAt = hb.createdAt
            hotel.updatedAt = hb.updatedAt
            hotel.needsSync = true
            context.insert(hotel)
        }
        for rb in backup.restaurants {
            let city = rb.cityID.flatMap { cityMap[$0] }
            let restaurant = PlaceRestaurant(nameEN: rb.nameEN, city: city)
            restaurant.id = UUID(uuidString: rb.id) ?? UUID()
            restaurant.nameZH = rb.nameZH
            restaurant.nameLocal = rb.nameLocal
            restaurant.address = rb.address
            restaurant.phone = rb.phone
            restaurant.cuisine = rb.cuisine
            restaurant.rating = rb.rating
            restaurant.specialty = rb.specialty
            restaurant.notes = rb.notes
            restaurant.createdAt = rb.createdAt
            restaurant.updatedAt = rb.updatedAt
            restaurant.needsSync = true
            context.insert(restaurant)
        }
        for ab in backup.attractions {
            let city = ab.cityID.flatMap { cityMap[$0] }
            let attraction = PlaceAttraction(nameEN: ab.nameEN, city: city)
            attraction.id = UUID(uuidString: ab.id) ?? UUID()
            attraction.nameZH = ab.nameZH
            attraction.nameLocal = ab.nameLocal
            attraction.address = ab.address
            attraction.phone = ab.phone
            attraction.ticketPrice = ab.ticketPrice
            attraction.openingHours = ab.openingHours
            attraction.photographyRules = ab.photographyRules
            attraction.allowedItems = ab.allowedItems
            attraction.notes = ab.notes
            attraction.createdAt = ab.createdAt
            attraction.updatedAt = ab.updatedAt
            attraction.needsSync = true
            context.insert(attraction)
        }

        // 還原地點照片
        for pb in backup.photos {
            guard let placeID = UUID(uuidString: pb.placeID),
                  let imageData = Data(base64Encoded: pb.imageData) else { continue }
            let photo = PlacePhoto(
                placeID: placeID,
                fileName: pb.fileName,
                category: pb.category,
                sortOrder: pb.sortOrder
            )
            photo.id = UUID(uuidString: pb.id) ?? UUID()
            photo.createdAt = pb.createdAt
            photo.needsUpload = true
            photo.needsDelete = false
            _ = PlacePhotoManager.shared.cachePhoto(data: imageData, fileName: pb.fileName)
            context.insert(photo)
        }

        // 還原個人資料
        if let profile = backup.profile {
            let defaults = UserDefaults.standard
            defaults.set(profile.nameZH, forKey: "profile_nameZH")
            defaults.set(profile.nameEN, forKey: "profile_nameEN")
            defaults.set(profile.phone, forKey: "profile_phone")
            defaults.set(profile.lineID, forKey: "profile_lineID")
            defaults.set(profile.notes, forKey: "profile_notes")
        }

        try context.save()

        let elapsed = Int(Date().timeIntervalSince(startTime))
        let fileSize = (try? fileInfo.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        return RestoreResult(
            teamCount: backup.teams.count,
            expenseCount: backup.expenses.count + backup.incomes.count + backup.tourFunds.count,
            journalCount: backup.journals.count,
            customTypeCount: backup.customFundTypes.count + backup.customIncomeTypes.count,
            cityCount: backup.cities.count,
            placeCount: backup.hotels.count + backup.restaurants.count + backup.attractions.count,
            photoCount: backup.photos.count,
            sourceDateStr: fileInfo.formattedDate,
            fileSizeBytes: fileSize,
            elapsedSeconds: elapsed
        )
    }

    // MARK: - 預覽備份內容（建立前顯示給使用者看）

    func previewBackup(context: ModelContext) -> BackupPreview {
        let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let incomes = (try? context.fetch(FetchDescriptor<Income>())) ?? []
        let tourFunds = (try? context.fetch(FetchDescriptor<TourFund>())) ?? []
        let journals = (try? context.fetch(FetchDescriptor<Journal>())) ?? []
        let customFundTypes = (try? context.fetch(FetchDescriptor<CustomFundType>())) ?? []
        let customIncomeTypes = (try? context.fetch(FetchDescriptor<CustomIncomeType>())) ?? []
        let cities = (try? context.fetch(FetchDescriptor<City>())) ?? []
        let hotels = (try? context.fetch(FetchDescriptor<PlaceHotel>()))?.filter { $0.remoteID == nil } ?? []
        let restaurants = (try? context.fetch(FetchDescriptor<PlaceRestaurant>()))?.filter { $0.remoteID == nil } ?? []
        let attractions = (try? context.fetch(FetchDescriptor<PlaceAttraction>()))?.filter { $0.remoteID == nil } ?? []
        let allPhotos = (try? context.fetch(FetchDescriptor<PlacePhoto>())) ?? []
        let pendingPhotos = allPhotos.filter { $0.needsUpload && $0.remoteURL == nil }

        // 計算照片大小
        var photoBytes = 0
        for photo in pendingPhotos {
            if let data = PlacePhotoManager.shared.loadImageData(fileName: photo.fileName) {
                photoBytes += data.count
            }
        }

        return BackupPreview(
            teamCount: teams.count,
            expenseCount: expenses.count + incomes.count + tourFunds.count,
            journalCount: journals.count,
            customTypeCount: customFundTypes.count + customIncomeTypes.count,
            cityCount: cities.count,
            placeCount: hotels.count + restaurants.count + attractions.count,
            photoCount: pendingPhotos.count,
            photoSizeBytes: photoBytes
        )
    }

    // MARK: - 刪除舊備份（保留最近 5 個）

    private func deleteOldBackups() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        )) ?? []

        let sorted = files
            .filter { $0.pathExtension == "json" }
            .sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return d1 > d2
            }

        if sorted.count > maxBackupCount {
            for url in sorted.dropFirst(maxBackupCount) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - 刪除單一備份

    func deleteBackup(_ fileInfo: BackupFileInfo) {
        try? FileManager.default.removeItem(at: fileInfo.fileURL)
    }
}

// MARK: - 還原結果

struct RestoreResult {
    let teamCount: Int
    let expenseCount: Int
    let journalCount: Int
    let customTypeCount: Int
    let cityCount: Int
    let placeCount: Int
    let photoCount: Int
    let sourceDateStr: String
    let fileSizeBytes: Int
    let elapsedSeconds: Int

    var fileSizeString: String {
        let mb = Double(fileSizeBytes) / 1_048_576
        if mb < 1 {
            let kb = Double(fileSizeBytes) / 1024
            return String(format: "%.1f KB", kb)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - 備份預覽資料

struct BackupPreview {
    let teamCount: Int
    let expenseCount: Int
    let journalCount: Int
    let customTypeCount: Int
    let cityCount: Int
    let placeCount: Int
    let photoCount: Int
    let photoSizeBytes: Int

    var photoSizeString: String {
        let mb = Double(photoSizeBytes) / 1_048_576
        if mb < 1 {
            let kb = Double(photoSizeBytes) / 1024
            return String(format: "%.1f KB", kb)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - DateFormatter 擴充

private extension DateFormatter {
    static let backupFileName: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f
    }()
}
