import Network
import Foundation

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private(set) var isOnCellular = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnCellular = path.usesInterfaceType(.cellular)
            }
        }
        monitor.start(queue: queue)
    }

    /// 計算指定 placeID 待上傳照片的本機檔案大小總和（位元組）
    func pendingUploadSize(fileNames: [String]) -> Int64 {
        let baseURL = PlacePhotoManager.shared.photosDirectory
        return fileNames.reduce(into: Int64(0)) { total, name in
            let url = baseURL.appendingPathComponent(name)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
            total += size
        }
    }

    /// 格式化為易讀字串，例如 "3.2 MB"
    func formattedSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb < 1 {
            let kb = Double(bytes) / 1024
            return String(format: "%.0f KB", kb)
        }
        return String(format: "%.1f MB", mb)
    }
}
