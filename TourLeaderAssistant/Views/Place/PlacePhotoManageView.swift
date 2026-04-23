import SwiftUI
import SwiftData
import PhotosUI

struct PlacePhotoManageView: View {
    @Environment(\.modelContext) private var modelContext

    let placeID: UUID
    let placeType: String
    let remoteID: UUID?
    let maxPhotos: Int

    @Query private var allPhotos: [PlacePhoto]

    @AppStorage("savePhotoToAlbum") private var savePhotoToAlbum = true

    @State private var isEditing = false
    @State private var showingSourcePicker = false
    @State private var showingCamera = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingLibrary = false
    @State private var fullscreenPhoto: PlacePhoto? = nil
    @State private var isProcessing = false

    @State private var isSyncing = false
    @State private var syncMessage: String? = nil
    @State private var showingUploadConfirm = false
    @State private var showingRefreshConfirm = false

    private let network = NetworkMonitor.shared

    var photos: [PlacePhoto] {
        allPhotos
            .filter { $0.placeID == placeID && !$0.needsDelete }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var hasPendingChanges: Bool {
        allPhotos.filter { $0.placeID == placeID }.contains { $0.needsUpload || $0.needsDelete }
    }

    var pendingUploadPhotoFileNames: [String] {
        allPhotos.filter { $0.placeID == placeID && $0.needsUpload }.map { $0.fileName }
    }

    var uploadAlertMessage: String {
        let base = "將把本機的照片新增與刪除同步到雲端，其他裝置同步後也會看到變更。確定繼續嗎？"
        if network.isOnCellular && !pendingUploadPhotoFileNames.isEmpty {
            let bytes = network.pendingUploadSize(fileNames: pendingUploadPhotoFileNames)
            let sizeStr = network.formattedSize(bytes)
            return "⚠️ 目前使用行動數據，預計上傳約 \(sizeStr)。\n\n\(base)"
        }
        return base
    }

    var canAddMore: Bool { photos.count < maxPhotos }
    var remaining: Int { maxPhotos - photos.count }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                if let message = syncMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color("AppSecondary"))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("AppCard"))
                }

                if photos.isEmpty && !hasPendingChanges {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title)
                            .foregroundStyle(Color("AppAccent").opacity(0.4))
                        Text("尚無照片")
                            .font(.callout).fontWeight(.semibold)
                        Text("點右上角 ＋ 新增")
                            .font(.subheadline)
                            .foregroundStyle(Color(.systemGray))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 4
                        ) {
                            ForEach(photos) { photo in
                                PhotoGridCell(
                                    photo: photo,
                                    isEditing: isEditing,
                                    onTap: { if !isEditing { fullscreenPhoto = photo } },
                                    onDelete: { deletePhoto(photo) }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                        if remoteID != nil {
                            VStack(spacing: 12) {
                                if hasPendingChanges {
                                    Button {
                                        showingUploadConfirm = true
                                    } label: {
                                        Label("同步雲端照片", systemImage: "arrow.up.circle")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color("AppAccent"))
                                    .disabled(isSyncing)
                                }

                                Button {
                                    showingRefreshConfirm = true
                                } label: {
                                    Label("更新本地照片", systemImage: "arrow.down.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(Color("AppSecondary"))
                                .disabled(isSyncing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                        }
                    }
                }
            }

            if isProcessing || isSyncing {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView(isSyncing ? "同步中…" : "處理中…")
                    .padding(20)
                    .background(Color("AppCard"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle("照片（\(photos.count)/\(maxPhotos)）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if !photos.isEmpty || isEditing {
                        HStack(spacing: 6) {
                            if hasPendingChanges {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Color("AppAccent"))
                                    .font(.subheadline)
                            }
                            Button(isEditing ? "完成" : "編輯") { isEditing.toggle() }
                                .foregroundStyle(Color("AppAccent"))
                        }
                    }
                    if canAddMore && !isEditing {
                        Button {
                            showingSourcePicker = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color("AppAccent"))
                        }
                    }
                }
            }
        }
        .confirmationDialog("新增照片", isPresented: $showingSourcePicker) {
            Button("拍照") { showingCamera = true }
            Button("從相簿選取") { showingLibrary = true }
            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                if savePhotoToAlbum {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
                savePhoto(image: image)
            }
        }
        .photosPicker(
            isPresented: $showingLibrary,
            selection: $selectedItems,
            maxSelectionCount: remaining,
            matching: .images
        )
        .onChange(of: selectedItems) {
            guard !selectedItems.isEmpty else { return }
            Task { await processSelectedItems() }
        }
        .fullScreenCover(item: $fullscreenPhoto) { photo in
            PhotoFullscreenView(photo: photo, photos: photos)
        }
        .alert("同步雲端照片", isPresented: $showingUploadConfirm) {
            Button("取消", role: .cancel) {}
            Button("確認上傳") { Task { await syncToCloud() } }
        } message: {
            Text(uploadAlertMessage)
        }
        .alert("更新本地照片", isPresented: $showingRefreshConfirm) {
            Button("取消", role: .cancel) {}
            Button("確認更新", role: .destructive) { Task { await refreshFromCloud() } }
        } message: {
            Text("將清除本機所有照片，並重新從雲端下載。本機尚未同步的照片將會遺失。確定繼續嗎？")
        }
    }

    // MARK: - 照片操作

    private func processSelectedItems() async {
        isProcessing = true
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                savePhoto(image: image)
            }
        }
        selectedItems = []
        isProcessing = false
    }

    private func savePhoto(image: UIImage) {
        guard photos.count < maxPhotos else { return }
        guard let fileName = PlacePhotoManager.shared.save(image: image) else { return }
        let nextOrder = (photos.map { $0.sortOrder }.max() ?? -1) + 1
        let photo = PlacePhoto(
            placeID: placeID,
            fileName: fileName,
            category: "",
            sortOrder: nextOrder
        )
        modelContext.insert(photo)
        syncMessage = nil
    }

    private func deletePhoto(_ photo: PlacePhoto) {
        PlacePhotoManager.shared.delete(fileName: photo.fileName)
        if photo.remoteURL != nil {
            photo.needsDelete = true
            photo.needsUpload = false
        } else {
            modelContext.delete(photo)
        }
        syncMessage = nil
    }

    // MARK: - 同步雲端照片

    private func syncToCloud() async {
        guard let remoteID else { return }
        isSyncing = true
        syncMessage = nil
        let result = await SupabaseManager.shared.syncPhotos(
            for: placeID,
            placeType: placeType,
            remoteID: remoteID,
            context: modelContext
        )
        isSyncing = false
        syncMessage = result.summary
    }

    // MARK: - 更新本地照片

    private func refreshFromCloud() async {
        guard let remoteID else { return }
        isSyncing = true
        syncMessage = nil
        let success = await SupabaseManager.shared.resetLocalPhotos(
            for: placeID,
            placeType: placeType,
            remoteID: remoteID,
            context: modelContext
        )
        isSyncing = false
        syncMessage = success ? "已從雲端重新下載照片" : "更新失敗，請確認網路連線"
    }
}

// MARK: - PhotoGridCell

struct PhotoGridCell: View {
    let photo: PlacePhoto
    let isEditing: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var image: UIImage? {
        PlacePhotoManager.shared.loadImage(fileName: photo.fileName)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(Color(.systemGray3))
                        }
                }
            }
            .frame(height: 120)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if isEditing {
                Button { onDelete() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .padding(4)
            }

            if photo.needsUpload && !isEditing {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .background(Color("AppAccent"), in: Circle())
                    .padding(4)
            }
        }
    }
}
