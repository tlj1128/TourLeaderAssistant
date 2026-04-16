import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "auto"
    @AppStorage("savePhotoToAlbum") private var savePhotoToAlbum = true
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    @Environment(\.modelContext) private var modelContext
    @Query private var hotels: [PlaceHotel]
    @Query private var restaurants: [PlaceRestaurant]
    @Query private var attractions: [PlaceAttraction]
    @Query private var allPhotos: [PlacePhoto]

    @State private var showClearCacheAlert = false
    @State private var showUnsyncedWarning = false
    @State private var unsyncedCount = 0
    @State private var downloadedCount = 0

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        NavigationStack {
            List {
                Section("個人") {
                    NavigationLink(destination: PersonalProfileView()) {
                        Label("個人基本資料", systemImage: "person.circle")
                    }
                }
                
                Section("備份與還原") {
                    NavigationLink(destination: iCloudBackupView()) {
                        Label("iCloud 備份", systemImage: "icloud")
                    }
                }

                Section("自訂資料") {
                    NavigationLink(destination: CountryManagementView()) {
                        Label("國家與城市管理", systemImage: "map")
                    }
                    NavigationLink(destination: FundTypeManageView()) {
                        Label("零用金類型", systemImage: "bag")
                    }
                    NavigationLink(destination: IncomeTypeManageView()) {
                        Label("收入類型", systemImage: "banknote")
                    }
                }

                Section("偏好設定") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("外觀")
                            .font(.subheadline)
                        Picker("外觀", selection: $appearance) {
                            Text("自動").tag("auto")
                            Text("淺色").tag("light")
                            Text("深色").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("介面文字大小")
                            .font(.subheadline)
                        Picker("介面文字大小", selection: $textSizePreference) {
                            Text("標準").tag("standard")
                            Text("大").tag("large")
                            Text("特大").tag("xlarge")
                            Text("超大").tag("xxlarge")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $savePhotoToAlbum) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("拍照後儲存至相簿")
                            Text("關閉後拍照不會存入系統相簿")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("地點庫快取") {
                    LabeledContent("照片快取大小") {
                        Text(PlacePhotoManager.shared.cacheSize())
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        let unsyncedHotels = hotels.filter { $0.remoteID != nil && $0.needsSync }
                        let unsyncedRestaurants = restaurants.filter { $0.remoteID != nil && $0.needsSync }
                        let unsyncedAttractions = attractions.filter { $0.remoteID != nil && $0.needsSync }
                        unsyncedCount = unsyncedHotels.count + unsyncedRestaurants.count + unsyncedAttractions.count
                        downloadedCount = hotels.filter { $0.remoteID != nil }.count
                            + restaurants.filter { $0.remoteID != nil }.count
                            + attractions.filter { $0.remoteID != nil }.count
                        if unsyncedCount > 0 {
                            showUnsyncedWarning = true
                        } else {
                            showClearCacheAlert = true
                        }
                    } label: {
                        Label("清除地點快取", systemImage: "trash")
                    }
                }

                Section("支持與回饋") {
                    NavigationLink(destination: DonateView()) {
                        Label("請開發者喝一杯", systemImage: "cup.and.saucer")
                    }
                    .foregroundStyle(.primary)

                    Button {
                        if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("為 App 評分", systemImage: "star")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        if let url = URL(string: "mailto:your@email.com?subject=領隊助手意見回饋") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("意見回饋", systemImage: "envelope")
                            .foregroundStyle(.primary)
                    }
                }

                Section("關於") {
                    LabeledContent("版本", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }
            }
            .navigationTitle("設定")
            .alert("確定清除地點快取？", isPresented: $showClearCacheAlert) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    clearDownloadedPlaces()
                }
            } message: {
                Text("將清除已下載的 \(downloadedCount) 個地點資料與照片，個人新增的本地資料不受影響。")
            }
            .alert("有未同步的修改", isPresented: $showUnsyncedWarning) {
                Button("取消", role: .cancel) {}
                Button("仍然清除", role: .destructive) {
                    clearDownloadedPlaces()
                }
            } message: {
                Text("有 \(unsyncedCount) 個地點有未同步的修改，清除後將遺失。確定繼續？")
            }
        }
    }

    // MARK: - Logic

    private func clearDownloadedPlaces() {
        // 收集要保留的照片（本機新增，從未上傳）
        let keepFileNames = Set(allPhotos.filter { $0.remoteURL == nil && $0.needsUpload }.map { $0.fileName })

        // 找出從雲端下載的地點
        let downloadedHotels = hotels.filter { $0.remoteID != nil }
        let downloadedRestaurants = restaurants.filter { $0.remoteID != nil }
        let downloadedAttractions = attractions.filter { $0.remoteID != nil }

        // 收集這些地點的 placeID
        let downloadedPlaceIDs = Set(
            downloadedHotels.map { $0.id } +
            downloadedRestaurants.map { $0.id } +
            downloadedAttractions.map { $0.id }
        )

        // 刪除對應的 PlacePhoto 記錄
        for photo in allPhotos where downloadedPlaceIDs.contains(photo.placeID) {
            modelContext.delete(photo)
        }

        // 刪除地點資料
        downloadedHotels.forEach { modelContext.delete($0) }
        downloadedRestaurants.forEach { modelContext.delete($0) }
        downloadedAttractions.forEach { modelContext.delete($0) }

        try? modelContext.save()

        // 清除照片檔案（保留本機新增的）
        PlacePhotoManager.shared.clearCache(excluding: keepFileNames)
    }
}
