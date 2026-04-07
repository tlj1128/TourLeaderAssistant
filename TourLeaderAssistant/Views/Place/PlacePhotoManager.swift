import UIKit
import SwiftData

class PlacePhotoManager {
    static let shared = PlacePhotoManager()
    private init() {}

    // MARK: - 目錄

    var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("PlacePhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - 儲存

    /// 壓縮並儲存照片，回傳檔名（儲存失敗回傳 nil）
    func save(image: UIImage) -> String? {
        let resized = resize(image: image, maxDimension: 1080)
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return nil }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("PlacePhotoManager 儲存失敗：\(error)")
            return nil
        }
    }

    // MARK: - 讀取

    func loadImage(fileName: String) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }

    // MARK: - 刪除

    func delete(fileName: String) {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    func deleteAll(for placeID: UUID, photos: [PlacePhoto]) {
        for photo in photos where photo.placeID == placeID {
            delete(fileName: photo.fileName)
        }
    }

    // MARK: - 快取大小

    func cacheSize() -> String {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: photosDirectory.path)) ?? []
        let totalBytes = files.reduce(0) { acc, name in
            let url = photosDirectory.appendingPathComponent(name)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            return acc + size
        }
        let mb = Double(totalBytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    func clearCache() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: photosDirectory.path)) ?? []
        for name in files {
            let url = photosDirectory.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - 壓縮

    private func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
