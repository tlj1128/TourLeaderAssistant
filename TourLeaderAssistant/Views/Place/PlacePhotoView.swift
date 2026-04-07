import SwiftUI
import SwiftData

// MARK: - PlacePhotoView（純顯示，modal 由父層控制）

struct PlacePhotoView: View {
    let photos: [PlacePhoto]
    let maxPhotos: Int
    let isEditing: Bool
    let onAddTapped: () -> Void
    let onDeletePhoto: (PlacePhoto) -> Void
    let onPhotoTapped: (PlacePhoto) -> Void
    let onEditToggled: () -> Void

    var canAddMore: Bool { photos.count < maxPhotos }

    var body: some View {
        Section {
            if photos.isEmpty && !isEditing {
                Button {
                    onAddTapped()
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(Color("AppAccent"))
                        Text("新增照片")
                            .foregroundStyle(Color("AppAccent"))
                    }
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(photos) { photo in
                        PhotoThumbnail(
                            photo: photo,
                            isEditing: isEditing,
                            onTap: { onPhotoTapped(photo) },
                            onDelete: { onDeletePhoto(photo) }
                        )
                    }
                    if canAddMore && isEditing {
                        Button { onAddTapped() } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .frame(height: 100)
                                .overlay {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundStyle(Color(.systemGray3))
                                }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("照片（\(photos.count)/\(maxPhotos)）")
                Spacer()
                if !photos.isEmpty || isEditing {
                    Button(isEditing ? "完成" : "編輯") {
                        onEditToggled()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color("AppAccent"))
                }
                if !isEditing && canAddMore && !photos.isEmpty {
                    Button { onAddTapped() } label: {
                        Image(systemName: "plus")
                            .font(.subheadline)
                            .foregroundStyle(Color("AppAccent"))
                    }
                }
            }
        }
    }
}

// MARK: - PhotoThumbnail

struct PhotoThumbnail: View {
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
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if isEditing {
                Button { onDelete() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .padding(4)
            }
        }
    }
}

// MARK: - ZoomableImageView（UIScrollView 實作）

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var resetTrigger: Bool = false
    var onZoomChanged: ((Bool) -> Void)?

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear
        scrollView.isScrollEnabled = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        // 雙擊固定放大到 2.5x 或縮回 1.0
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        imageView.image = image

        // 換頁時重置縮放
        if context.coordinator.lastResetTrigger != resetTrigger {
            context.coordinator.lastResetTrigger = resetTrigger
            scrollView.setZoomScale(1.0, animated: false)
            scrollView.isScrollEnabled = false
            onZoomChanged?(false)
        }

        DispatchQueue.main.async {
            let size = scrollView.bounds.size
            guard size.width > 0 && size.height > 0 else { return }
            imageView.frame = CGRect(origin: .zero, size: size)
            scrollView.contentSize = size
            context.coordinator.centerImageView(in: scrollView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onZoomChanged: onZoomChanged)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        var onZoomChanged: ((Bool) -> Void)?
        var lastResetTrigger: Bool = false

        init(onZoomChanged: ((Bool) -> Void)?) {
            self.onZoomChanged = onZoomChanged
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageView(in: scrollView)
            let isZoomed = scrollView.zoomScale > 1.01
            scrollView.isScrollEnabled = isZoomed
            onZoomChanged?(isZoomed)
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            if scale <= 1.0 {
                scrollView.isScrollEnabled = false
                onZoomChanged?(false)
            }
        }

        func centerImageView(in scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            frameToCenter.origin.x = frameToCenter.size.width < boundsSize.width
                ? (boundsSize.width - frameToCenter.size.width) / 2 : 0
            frameToCenter.origin.y = frameToCenter.size.height < boundsSize.height
                ? (boundsSize.height - frameToCenter.size.height) / 2 : 0

            imageView.frame = frameToCenter
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > 1.0 {
                // 縮回 1.0
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                // 固定放大到 2.5，以畫面中心為基準
                let center = CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY)
                let newScale: CGFloat = 2.5
                let w = scrollView.bounds.width / newScale
                let h = scrollView.bounds.height / newScale
                let zoomRect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}

// MARK: - PhotoFullscreenView

struct PhotoFullscreenView: View {
    let photo: PlacePhoto
    let photos: [PlacePhoto]
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var resetTrigger: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, p in
                    if let img = PlacePhotoManager.shared.loadImage(fileName: p.fileName) {
                        VStack(spacing: 8) {
                            ZoomableImageView(
                                image: img,
                                resetTrigger: resetTrigger
                            )
                            if !p.category.isEmpty {
                                Text(p.category)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(.systemGray3))
                            }
                        }
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .onChange(of: currentIndex) { _, _ in
                // 切換頁面時觸發所有 ZoomableImageView 重置
                resetTrigger.toggle()
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            currentIndex = photos.firstIndex(where: { $0.id == photo.id }) ?? 0
        }
    }
}

// MARK: - CameraView

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - LibraryPickerView

struct LibraryPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
