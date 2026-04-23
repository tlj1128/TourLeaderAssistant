import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "auto"
    @AppStorage("savePhotoToAlbum") private var savePhotoToAlbum = true
    @AppStorage("textSizePreference") private var textSizePreference = "standard"
    @AppStorage("useLocalAI") private var useLocalAI = false

    @Environment(\.modelContext) private var modelContext
    @Query private var hotels: [PlaceHotel]
    @Query private var restaurants: [PlaceRestaurant]
    @Query private var attractions: [PlaceAttraction]
    @Query private var allPhotos: [PlacePhoto]

    @State private var showClearCacheAlert = false
    @State private var showUnsyncedWarning = false
    @State private var showFeedback = false
    @State private var unsyncedCount = 0
    @State private var downloadedCount = 0

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    /// 是否支援 Apple Intelligence（iOS 26+ 且模型可用）
    private var isAppleIntelligenceSupported: Bool {
        if #available(iOS 26, *) {
            return FoundationModelManager.shared.isAvailable
        }
        return false
    }

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

                // MARK: - Apple Intelligence
                Section {
                    if isAppleIntelligenceSupported {
                        Toggle(isOn: $useLocalAI) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Intelligence 輔助")
                                Text("啟用後將使用裝置內建 Apple Intelligence 進行語意輔助分析")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.intelligence")
                                .foregroundStyle(Color(.systemGray3))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Intelligence 輔助")
                                    .foregroundStyle(Color(.systemGray))
                                Text("需要 iPhone 15 Pro 以上裝置並已開啟 Apple Intelligence")
                                    .font(.caption)
                                    .foregroundStyle(Color(.systemGray3))
                            }
                        }
                    }
                } header: {
                    Text("智慧功能")
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

                    Button {
                        UIApplication.shared.open(AppConfigManager.shared.linktreeURL)
                    } label: {
                        Label {
                            Text("關注「消業障旅行團」")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "mic")
                        }
                    }

                    Button {
                        if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label {
                            Text("為 App 評分")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "star")
                        }
                    }

                    Button {
                        showFeedback = true
                    } label: {
                        Label {
                            Text("意見回饋")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "envelope")
                        }
                    }
                }

                Section("說明") {
                    Button {
                        UIApplication.shared.open(AppConfigManager.shared.userGuideURL)
                    } label: {
                        Label {
                            Text("使用說明")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "questionmark.circle")
                        }
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
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
                    .appDynamicTypeSize(textSizePreference)
            }
        }
    }

    // MARK: - Logic

    private func clearDownloadedPlaces() {
        let keepFileNames = Set(allPhotos.filter { $0.remoteURL == nil && $0.needsUpload }.map { $0.fileName })

        let downloadedHotels = hotels.filter { $0.remoteID != nil }
        let downloadedRestaurants = restaurants.filter { $0.remoteID != nil }
        let downloadedAttractions = attractions.filter { $0.remoteID != nil }

        let downloadedPlaceIDs = Set(
            downloadedHotels.map { $0.id } +
            downloadedRestaurants.map { $0.id } +
            downloadedAttractions.map { $0.id }
        )

        for photo in allPhotos where downloadedPlaceIDs.contains(photo.placeID) {
            modelContext.delete(photo)
        }

        downloadedHotels.forEach { modelContext.delete($0) }
        downloadedRestaurants.forEach { modelContext.delete($0) }
        downloadedAttractions.forEach { modelContext.delete($0) }

        try? modelContext.save()

        PlacePhotoManager.shared.clearCache(excluding: keepFileNames)
    }
}
