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

    // MARK: - 儲存（本機新增照片用）

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

    // MARK: - 快取（從雲端下載後寫入本機用）

    /// 將下載回來的 Data 寫入本機快取，fileName 由 remoteURL 的最後路徑元件決定
    func cachePhoto(data: Data, fileName: String) -> Bool {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("PlacePhotoManager 快取失敗：\(error)")
            return false
        }
    }

    /// 檢查本機是否已有該檔名的快取
    func hasCached(fileName: String) -> Bool {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - 讀取

    func loadImage(fileName: String) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }

    /// 讀取照片原始 Data（上傳用）
    func loadImageData(fileName: String) -> Data? {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
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

    func clearCache(excluding fileNames: Set<String> = []) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: photosDirectory.path)) ?? []
        for name in files where !fileNames.contains(name) {
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
