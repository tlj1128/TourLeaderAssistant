import SwiftUI
import SwiftData

struct RestaurantDetailView: View {
    let restaurant: PlaceRestaurant
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    @State private var isSyncing = false
    @State private var syncMessage: String? = nil
    @State private var showingUploadConfirm = false
    @State private var showingRefreshConfirm = false

    @Query private var allPhotos: [PlacePhoto]
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    private let network = NetworkMonitor.shared

    var photos: [PlacePhoto] {
        allPhotos
            .filter { $0.placeID == restaurant.id && !$0.needsDelete }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var hasPendingChanges: Bool {
        restaurant.needsSync ||
        allPhotos.filter { $0.placeID == restaurant.id }.contains { $0.needsUpload || $0.needsDelete }
    }

    var pendingUploadPhotoFileNames: [String] {
        allPhotos.filter { $0.placeID == restaurant.id && $0.needsUpload }.map { $0.fileName }
    }

    var uploadAlertMessage: String {
        let base = "將把這筆資料與照片的異動同步到雲端，其他裝置同步後也會看到變更。確定繼續嗎？"
        if network.isOnCellular && !pendingUploadPhotoFileNames.isEmpty {
            let bytes = network.pendingUploadSize(fileNames: pendingUploadPhotoFileNames)
            let sizeStr = network.formattedSize(bytes)
            return "⚠️ 目前使用行動數據，預計上傳約 \(sizeStr)。\n\n\(base)"
        }
        return base
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                Section {
                    NavigationLink(destination: PlacePhotoManageView(
                        placeID: restaurant.id,
                        placeType: "restaurant",
                        remoteID: restaurant.remoteID,
                        maxPhotos: 10
                    )) {
                        if photos.isEmpty {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .foregroundStyle(Color("AppAccent"))
                                Text("新增照片")
                                    .foregroundStyle(Color("AppAccent"))
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(photos.prefix(5)) { photo in
                                        if let img = PlacePhotoManager.shared.loadImage(fileName: photo.fileName) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    if photos.count > 5 {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.systemGray5))
                                                .frame(width: 80, height: 80)
                                            Text("+\(photos.count - 5)")
                                                .font(.body).fontWeight(.semibold)
                                                .foregroundStyle(Color(.systemGray))
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listRowBackground(Color("AppCard"))
                } header: {
                    Text("照片（\(photos.count)/10）")
                }

                if hasPendingChanges && restaurant.remoteID != nil {
                    Section {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Color("AppAccent"))
                                .font(.footnote)
                            Text("資料有未同步的修改")
                                .font(.footnote)
                                .foregroundStyle(Color("AppAccent"))
                        }
                        .listRowBackground(Color("AppAccent").opacity(0.08))
                    }
                }

                Section("基本資訊") {
                    LabeledContent("英文名稱", value: restaurant.nameEN)
                        .listRowBackground(Color("AppCard"))
                    if !restaurant.nameZH.isEmpty {
                        LabeledContent("中文名稱", value: restaurant.nameZH)
                            .listRowBackground(Color("AppCard"))
                    }
                    if !restaurant.nameLocal.isEmpty {
                        LabeledContent("當地語言", value: restaurant.nameLocal)
                            .listRowBackground(Color("AppCard"))
                    }
                    if let city = restaurant.city {
                        LabeledContent("城市") {
                            HStack(spacing: 4) {
                                if let code = city.country?.code { Text(code.flag) }
                                Text(city.fullDisplayName)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !restaurant.address.isEmpty {
                        HStack {
                            Text("地址").foregroundStyle(.primary)
                            Spacer()
                            Button {
                                let encoded = restaurant.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "maps://?q=\(encoded)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(restaurant.address)
                                    .foregroundStyle(Color(hex: "5B8CDB"))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !restaurant.phone.isEmpty {
                        let phoneCode = restaurant.city?.country?.phoneCode ?? ""
                        let fullPhone = phoneCode.isEmpty ? restaurant.phone : "\(phoneCode) \(restaurant.phone)"
                        let dialNumber = fullPhone.filter { $0.isNumber || $0 == "+" }
                        HStack {
                            Text("電話").foregroundStyle(.primary)
                            Spacer()
                            Button {
                                if let url = URL(string: "tel://\(dialNumber)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(fullPhone)
                                    .foregroundStyle(Color(hex: "5B8CDB"))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                }

                if !restaurant.cuisine.isEmpty || !restaurant.rating.isEmpty || !restaurant.specialty.isEmpty
                    || !restaurant.capacity.isEmpty || !restaurant.paymentMethods.isEmpty || !restaurant.groupDiscount.isEmpty {
                    Section("餐廳資訊") {
                        if !restaurant.cuisine.isEmpty { LabeledContent("菜系", value: restaurant.cuisine).listRowBackground(Color("AppCard")) }
                        if !restaurant.rating.isEmpty { LabeledContent("評價", value: restaurant.rating).listRowBackground(Color("AppCard")) }
                        if !restaurant.specialty.isEmpty { LabeledContent("特色菜", value: restaurant.specialty).listRowBackground(Color("AppCard")) }
                        if !restaurant.capacity.isEmpty { LabeledContent("容客數", value: restaurant.capacity).listRowBackground(Color("AppCard")) }
                        if !restaurant.paymentMethods.isEmpty { LabeledContent("付款方式", value: restaurant.paymentMethods).listRowBackground(Color("AppCard")) }
                        if !restaurant.groupDiscount.isEmpty { LabeledContent("團體優惠", value: restaurant.groupDiscount).listRowBackground(Color("AppCard")) }
                    }
                }

                if !restaurant.notes.isEmpty {
                    Section("注意事項") {
                        Text(restaurant.notes)
                            .font(.subheadline)
                            .lineSpacing(4)
                            .listRowBackground(Color("AppCard"))
                    }
                }

                if let message = syncMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Color("AppSecondary"))
                            .listRowBackground(Color("AppCard"))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            if isSyncing {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("同步中…")
                    .padding(20)
                    .background(Color("AppCard"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle(restaurant.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if restaurant.remoteID != nil {
                        if hasPendingChanges {
                            Button {
                                showingUploadConfirm = true
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(Color("AppAccent"))
                            }
                            .disabled(isSyncing)
                        }
                        Button {
                            showingRefreshConfirm = true
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(Color("AppAccent"))
                        }
                        .disabled(isSyncing)
                    }
                    Button("編輯") { showingEdit = true }
                        .foregroundStyle(Color("AppAccent"))
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditRestaurantView(restaurant: restaurant)
                .appDynamicTypeSize(textSizePreference)
        }
        .alert("同步雲端", isPresented: $showingUploadConfirm) {
            Button("取消", role: .cancel) {}
            Button("確認上傳") { Task { await syncToCloud() } }
        } message: {
            Text(uploadAlertMessage)
        }
        .alert("更新本地", isPresented: $showingRefreshConfirm) {
            Button("取消", role: .cancel) {}
            Button("確認更新", role: .destructive) { Task { await refreshFromCloud() } }
        } message: {
            Text("將以雲端最新資料覆蓋這筆本機資料（含照片），本機未同步的異動將會遺失。確定繼續嗎？")
        }
    }

    private func syncToCloud() async {
        guard let remoteID = restaurant.remoteID else { return }
        isSyncing = true
        syncMessage = nil
        let dataSuccess = await SupabaseManager.shared.uploadRestaurant(restaurant, context: modelContext)
        let photoResult = await SupabaseManager.shared.syncPhotos(for: restaurant.id, placeType: "restaurant", remoteID: remoteID, context: modelContext)
        isSyncing = false
        syncMessage = dataSuccess
            ? (photoResult.summary.isEmpty ? "同步完成" : photoResult.summary)
            : "資料同步失敗，請確認城市是否已同步"
    }

    private func refreshFromCloud() async {
        isSyncing = true
        syncMessage = nil
        let success = await SupabaseManager.shared.refreshLocalRestaurant(restaurant, context: modelContext)
        isSyncing = false
        syncMessage = success ? "已從雲端更新本機資料" : "更新失敗，請確認網路連線"
    }
}
