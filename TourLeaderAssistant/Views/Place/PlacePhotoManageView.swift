import SwiftUI
import SwiftData
import PhotosUI

struct PlacePhotoManageView: View {
    @Environment(\.modelContext) private var modelContext

    let placeID: UUID
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

    var photos: [PlacePhoto] {
        allPhotos
            .filter { $0.placeID == placeID }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var canAddMore: Bool { photos.count < maxPhotos }
    var remaining: Int { maxPhotos - photos.count }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if photos.isEmpty {
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
                }
            }

            if isProcessing {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("處理中…")
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
                    if !photos.isEmpty {
                        Button(isEditing ? "完成" : "編輯") {
                            isEditing.toggle()
                        }
                        .foregroundStyle(Color("AppAccent"))
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
    }

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
    }

    private func deletePhoto(_ photo: PlacePhoto) {
        PlacePhotoManager.shared.delete(fileName: photo.fileName)
        modelContext.delete(photo)
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
        }
    }
}
