import SwiftUI
import SwiftData

struct AttractionDetailView: View {
    let attraction: PlaceAttraction
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    @State private var isSyncing = false
    @State private var syncMessage: String? = nil
    @State private var showingUploadConfirm = false
    @State private var showingRefreshConfirm = false

    @Query private var allPhotos: [PlacePhoto]
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var photos: [PlacePhoto] {
        allPhotos
            .filter { $0.placeID == attraction.id && !$0.needsDelete }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var hasPendingChanges: Bool {
        attraction.needsSync ||
        allPhotos.filter { $0.placeID == attraction.id }.contains { $0.needsUpload || $0.needsDelete }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                Section {
                    NavigationLink(destination: PlacePhotoManageView(
                        placeID: attraction.id,
                        placeType: "attraction",
                        remoteID: attraction.remoteID,
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

                // 異動提示
                if hasPendingChanges && attraction.remoteID != nil {
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
                    LabeledContent("英文名稱", value: attraction.nameEN)
                        .listRowBackground(Color("AppCard"))
                    if !attraction.nameZH.isEmpty {
                        LabeledContent("中文名稱", value: attraction.nameZH)
                            .listRowBackground(Color("AppCard"))
                    }
                    if !attraction.nameLocal.isEmpty {
                        LabeledContent("當地語言", value: attraction.nameLocal)
                            .listRowBackground(Color("AppCard"))
                    }
                    if let city = attraction.city {
                        LabeledContent("城市") {
                            HStack(spacing: 4) {
                                if let code = city.country?.code { Text(code.flag) }
                                Text(city.fullDisplayName)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !attraction.address.isEmpty {
                        HStack {
                            Text("地址").foregroundStyle(.primary)
                            Spacer()
                            Button {
                                let encoded = attraction.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                if let url = URL(string: "maps://?q=\(encoded)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text(attraction.address)
                                    .foregroundStyle(Color(hex: "5B8CDB"))
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .listRowBackground(Color("AppCard"))
                    }
                    if !attraction.phone.isEmpty {
                        let phoneCode = attraction.city?.country?.phoneCode ?? ""
                        let fullPhone = phoneCode.isEmpty ? attraction.phone : "\(phoneCode) \(attraction.phone)"
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

                if !attraction.ticketPrice.isEmpty || !attraction.openingHours.isEmpty {
                    Section("景點資訊") {
                        if !attraction.ticketPrice.isEmpty {
                            LabeledContent("票價", value: attraction.ticketPrice).listRowBackground(Color("AppCard"))
                        }
                        if !attraction.openingHours.isEmpty {
                            LabeledContent("開放時間", value: attraction.openingHours).listRowBackground(Color("AppCard"))
                        }
                    }
                }

                if !attraction.photographyRules.isEmpty || !attraction.allowedItems.isEmpty || !attraction.notes.isEmpty {
                    Section("注意事項") {
                        if !attraction.photographyRules.isEmpty {
                            LabeledContent("攝影規定", value: attraction.photographyRules).listRowBackground(Color("AppCard"))
                        }
                        if !attraction.allowedItems.isEmpty {
                            LabeledContent("物品規定", value: attraction.allowedItems).listRowBackground(Color("AppCard"))
                        }
                        if !attraction.notes.isEmpty {
                            Text(attraction.notes)
                                .font(.subheadline)
                                .lineSpacing(4)
                                .listRowBackground(Color("AppCard"))
                        }
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
        .navigationTitle(attraction.nameEN)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if attraction.remoteID != nil {
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
            EditAttractionView(attraction: attraction)
                .appDynamicTypeSize(textSizePreference)
        }
        .alert("同步雲端", isPresented: $showingUploadConfirm) {
            Button("取消", role: .cancel) {}
            Button("確認上傳") { Task { await syncToCloud() } }
        } message: {
            Text("將把這筆資料與照片的異動同步到雲端，其他裝置同步後也會看到變更。確定繼續嗎？")
        }
        .alert("更新本地", isPresented: $showingRefreshConfirm) {
            Button("取消", role: .cancel) {}
            Button("確認更新", role: .destructive) { Task { await refreshFromCloud() } }
        } message: {
            Text("將以雲端最新資料覆蓋這筆本機資料（含照片），本機未同步的異動將會遺失。確定繼續嗎？")
        }
    }

    private func syncToCloud() async {
        guard let remoteID = attraction.remoteID else { return }
        isSyncing = true
        syncMessage = nil
        let dataSuccess = await SupabaseManager.shared.uploadAttraction(attraction, context: modelContext)
        let photoResult = await SupabaseManager.shared.syncPhotos(for: attraction.id, placeType: "attraction", remoteID: remoteID, context: modelContext)
        isSyncing = false
        syncMessage = dataSuccess
            ? (photoResult.summary.isEmpty ? "同步完成" : photoResult.summary)
            : "資料同步失敗，請確認城市是否已同步"
    }

    private func refreshFromCloud() async {
        isSyncing = true
        syncMessage = nil
        let success = await SupabaseManager.shared.refreshLocalAttraction(attraction, context: modelContext)
        isSyncing = false
        syncMessage = success ? "已從雲端更新本機資料" : "更新失敗，請確認網路連線"
    }
}
