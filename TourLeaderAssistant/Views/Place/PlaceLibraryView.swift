import SwiftUI
import SwiftData

struct PlaceLibraryView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: PlaceLibraryTab = .hotel
    @State private var searchText = ""
    @State private var isSyncing = false
    @State private var syncMessage: String? = nil

    @State private var searchPreviews = PlaceSearchPreviews()
    @State private var isCloudSearching = false
    @State private var debounceTask: Task<Void, Never>? = nil

    @State private var showingUploadConfirm = false
    @State private var showingRefreshConfirm = false

    @Query private var allHotels: [PlaceHotel]
    @Query private var allRestaurants: [PlaceRestaurant]
    @Query private var allAttractions: [PlaceAttraction]
    @Query private var allPhotos: [PlacePhoto]

    private let network = NetworkMonitor.shared
    private var isSearching: Bool { !searchText.isEmpty }

    var hasPendingChanges: Bool {
        allHotels.contains { $0.needsSync } ||
        allRestaurants.contains { $0.needsSync } ||
        allAttractions.contains { $0.needsSync } ||
        allPhotos.contains { $0.needsUpload || $0.needsDelete }
    }

    var pendingUploadCount: Int {
        allHotels.filter { $0.needsSync }.count +
        allRestaurants.filter { $0.needsSync }.count +
        allAttractions.filter { $0.needsSync }.count
    }

    var localCloudCount: Int {
        allHotels.filter { $0.remoteID != nil }.count +
        allRestaurants.filter { $0.remoteID != nil }.count +
        allAttractions.filter { $0.remoteID != nil }.count
    }

    /// 待上傳照片的檔名清單（needsUpload = true）
    var pendingUploadPhotoFileNames: [String] {
        allPhotos.filter { $0.needsUpload }.map { $0.fileName }
    }

    var uploadAlertMessage: String {
        let photoCount = allPhotos.filter { $0.needsUpload || $0.needsDelete }.count
        let parts: [String] = [
            pendingUploadCount > 0 ? "地點 \(pendingUploadCount) 筆" : nil,
            photoCount > 0 ? "照片異動 \(photoCount) 張" : nil
        ].compactMap { $0 }
        let base = "將上傳 \(parts.joined(separator: "、")) 到雲端，供其他裝置同步使用。確定繼續嗎？"
        if network.isOnCellular && !pendingUploadPhotoFileNames.isEmpty {
            let bytes = network.pendingUploadSize(fileNames: pendingUploadPhotoFileNames)
            let sizeStr = network.formattedSize(bytes)
            return "⚠️ 目前使用行動數據，預計上傳約 \(sizeStr)。\n\n\(base)"
        }
        return base
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(visibleTabs) { tab in
                                tabButton(tab)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    Divider()

                    tabContent
                }
            }
            .navigationTitle("地點庫")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋地點名稱")
            .onChange(of: searchText) { _, newValue in
                handleSearchTextChange(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if isSyncing {
                            ProgressView().scaleEffect(0.85)
                        } else {
                            Button {
                                if hasPendingChanges {
                                    showingUploadConfirm = true
                                } else {
                                    showMessage("目前沒有待上傳的資料")
                                }
                            } label: {
                                Image(systemName: "arrow.up.circle")
                                    .foregroundStyle(Color("AppAccent"))
                            }

                            Button {
                                showingRefreshConfirm = true
                            } label: {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(Color("AppAccent"))
                            }
                        }
                    }
                }
            }
            .task {
                await SupabaseManager.shared.syncCountriesAndCities(context: modelContext)
            }
            .safeAreaInset(edge: .bottom) {
                if let message = syncMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75), in: Capsule())
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: syncMessage)
            .animation(.easeInOut(duration: 0.2), value: isSearching)
            .alert("同步雲端", isPresented: $showingUploadConfirm) {
                Button("取消", role: .cancel) {}
                Button("確認上傳") {
                    Task { await uploadToCloud() }
                }
            } message: {
                Text(uploadAlertMessage)
            }
            .alert("更新本地", isPresented: $showingRefreshConfirm) {
                Button("取消", role: .cancel) {}
                Button("確認更新", role: .destructive) {
                    Task { await refreshFromCloud() }
                }
            } message: {
                Text("將以雲端最新資料覆蓋本機所有已下載的地點（共 \(localCloudCount) 筆），本機未同步的異動將會遺失。確定繼續嗎？")
            }
        }
    }

    // MARK: - Tab

    private var visibleTabs: [PlaceLibraryTab] {
        isSearching
            ? [.searchResult, .hotel, .restaurant, .attraction]
            : [.hotel, .restaurant, .attraction]
    }

    @ViewBuilder
    private func tabButton(_ tab: PlaceLibraryTab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
        } label: {
            VStack(spacing: 4) {
                Text(tabLabel(tab))
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color("AppAccent") : Color("AppSecondary"))
                    .animation(.none, value: isSelected)
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(isSelected ? Color("AppAccent") : .clear)
                    .cornerRadius(1)
            }
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tabLabel(_ tab: PlaceLibraryTab) -> String {
        switch tab {
        case .searchResult:
            let total = searchPreviews.hotelCount + searchPreviews.restaurantCount + searchPreviews.attractionCount
            return total > 0 ? "全部 (\(total))" : "全部"
        case .hotel:
            return isSearching && searchPreviews.hotelCount > 0 ? "飯店 (\(searchPreviews.hotelCount))" : "飯店"
        case .restaurant:
            return isSearching && searchPreviews.restaurantCount > 0 ? "餐廳 (\(searchPreviews.restaurantCount))" : "餐廳"
        case .attraction:
            return isSearching && searchPreviews.attractionCount > 0 ? "景點 (\(searchPreviews.attractionCount))" : "景點"
        }
    }

    // MARK: - 內容區

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .searchResult:
            PlaceSearchResultView(previews: $searchPreviews, isSearching: isCloudSearching, showSectionHeaders: true)
        case .hotel:
            if isSearching {
                PlaceSearchResultView(previews: $searchPreviews, isSearching: isCloudSearching, filterType: .hotel, showSectionHeaders: false)
            } else {
                HotelListView(searchText: "")
            }
        case .restaurant:
            if isSearching {
                PlaceSearchResultView(previews: $searchPreviews, isSearching: isCloudSearching, filterType: .restaurant, showSectionHeaders: false)
            } else {
                RestaurantListView(searchText: "")
            }
        case .attraction:
            if isSearching {
                PlaceSearchResultView(previews: $searchPreviews, isSearching: isCloudSearching, filterType: .attraction, showSectionHeaders: false)
            } else {
                AttractionListView(searchText: "")
            }
        }
    }

    // MARK: - 搜尋

    private func handleSearchTextChange(_ newValue: String) {
        debounceTask?.cancel()
        if newValue.isEmpty {
            searchPreviews = PlaceSearchPreviews()
            isCloudSearching = false
            if selectedTab == .searchResult { selectedTab = .hotel }
            return
        }
        if selectedTab != .searchResult { selectedTab = .searchResult }
        searchPreviews = PlaceSearchPreviews(
            hotels: SupabaseManager.shared.localHotelPreviews(query: newValue, context: modelContext),
            restaurants: SupabaseManager.shared.localRestaurantPreviews(query: newValue, context: modelContext),
            attractions: SupabaseManager.shared.localAttractionPreviews(query: newValue, context: modelContext)
        )
        isCloudSearching = true
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            let result = await SupabaseManager.shared.searchPlacePreviews(query: newValue, context: modelContext)
            guard !Task.isCancelled else { return }
            searchPreviews = result
            isCloudSearching = false
        }
    }

    // MARK: - 同步雲端

    private func uploadToCloud() async {
        isSyncing = true
        syncMessage = nil
        await SupabaseManager.shared.syncCountriesAndCities(context: modelContext)
        let result = await SupabaseManager.shared.uploadPendingPlaces(context: modelContext)
        showMessage(result.summary)
        isSyncing = false
    }

    // MARK: - 更新本地

    private func refreshFromCloud() async {
        isSyncing = true
        syncMessage = nil
        let result = await SupabaseManager.shared.refreshAllLocalPlaces(context: modelContext)
        showMessage(result.summary)
        isSyncing = false
    }

    private func showMessage(_ message: String) {
        syncMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            syncMessage = nil
        }
    }
}

// MARK: - Tab 類型

enum PlaceLibraryTab: String, CaseIterable, Identifiable {
    case searchResult, hotel, restaurant, attraction
    var id: String { rawValue }
}
