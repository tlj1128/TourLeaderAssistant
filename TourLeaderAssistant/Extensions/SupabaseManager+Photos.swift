import Foundation
import SwiftData
import Supabase

// MARK: - 照片雲端同步

extension SupabaseManager {

    // MARK: - 輔助：storage path 組合與解析

    /// 組合 storage path：hotel/uuid/filename.jpg
    private func storagePath(placeType: String, placeRemoteID: UUID, fileName: String) -> String {
        "\(placeType)/\(placeRemoteID.uuidString)/\(fileName)"
    }

    /// 從 storage path 組合公開 URL
    func publicURL(for path: String) -> String {
        guard let base = try? client.storage.from("place-photos").getPublicURL(path: path) else {
            return ""
        }
        return base.absoluteString
    }

    // MARK: - 主要入口：同步單一地點的照片

    func syncPhotos(
        for placeID: UUID,
        placeType: String,
        remoteID: UUID,
        context: ModelContext
    ) async -> PhotoSyncResult {

        var uploaded = 0
        var deleted = 0
        var failed = 0

        let allDescriptor = FetchDescriptor<PlacePhoto>(
            predicate: #Predicate { $0.placeID == placeID }
        )
        guard let allPhotos = try? context.fetch(allDescriptor) else {
            return PhotoSyncResult()
        }

        let activePhotos = allPhotos.filter { !$0.needsDelete }
        let deletePhotos = allPhotos.filter { $0.needsDelete }

        // 取得雲端照片清單
        let remotePhotos = await fetchRemotePhotoRecords(placeRemoteID: remoteID, placeType: placeType)
        let localFileNames = Set(activePhotos.map { $0.fileName })

        // 1. 上傳本機有、標記 needsUpload 的
        for photo in activePhotos where photo.needsUpload {
            let result = await uploadPhoto(photo: photo, placeRemoteID: remoteID, placeType: placeType)
            if result {
                photo.needsUpload = false
                uploaded += 1
            } else {
                failed += 1
            }
        }

        // 2. 處理本機標記 needsDelete 的
        for photo in deletePhotos {
            if photo.remoteURL == nil {
                // 從未上傳過，直接清掉
                PlacePhotoManager.shared.delete(fileName: photo.fileName)
                context.delete(photo)
                continue
            }
            let path = storagePath(placeType: placeType, placeRemoteID: remoteID, fileName: photo.fileName)
            let result = await deleteRemotePhoto(storagePath: path, fileName: photo.fileName, placeRemoteID: remoteID)
            if result {
                PlacePhotoManager.shared.delete(fileName: photo.fileName)
                context.delete(photo)
                deleted += 1
            } else {
                failed += 1
            }
        }

        // 已在第 2 步處理過的 fileName
        let handledFileNames = Set(deletePhotos.compactMap { $0.remoteURL != nil ? $0.fileName : nil })

        // 3. 雲端有、本機沒有對應記錄的 → 從雲端刪除
        for remotePhoto in remotePhotos
            where !localFileNames.contains(remotePhoto.fileName)
            && !handledFileNames.contains(remotePhoto.fileName) {
            let path = storagePath(placeType: placeType, placeRemoteID: remoteID, fileName: remotePhoto.fileName)
                let result = await deleteRemotePhoto(storagePath: path, fileName: remotePhoto.fileName, placeRemoteID: remoteID)
            if result { deleted += 1 } else { failed += 1 }
        }

        try? context.save()
        return PhotoSyncResult(uploaded: uploaded, deleted: deleted, failed: failed)
    }

    // MARK: - 取得雲端照片記錄

    func fetchRemotePhotoRecords(placeRemoteID: UUID, placeType: String) async -> [RemotePhotoRecord] {
        do {
            let records: [RemotePhotoRecord] = try await client
                .from("place_photos")
                .select("id, storage_path, file_name, sort_order")
                .eq("place_id", value: placeRemoteID.uuidString)
                .eq("place_type", value: placeType)
                .order("sort_order")
                .execute()
                .value
            return records
        } catch {
            print("取得雲端照片失敗：\(error)")
            return []
        }
    }

    // MARK: - 上傳單張照片

    private func uploadPhoto(photo: PlacePhoto, placeRemoteID: UUID, placeType: String) async -> Bool {
        guard let imageData = PlacePhotoManager.shared.loadImageData(fileName: photo.fileName) else {
            print("照片讀取失敗：\(photo.fileName)")
            return false
        }

        let path = storagePath(placeType: placeType, placeRemoteID: placeRemoteID, fileName: photo.fileName)

        do {
            // 上傳到 Supabase Storage
            try await client.storage
                .from("place-photos")
                .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))

            // 寫入 place_photos 資料表
            let payload = PhotoPayload(
                placeID: placeRemoteID,
                placeType: placeType,
                storagePath: path,
                fileName: photo.fileName,
                sortOrder: photo.sortOrder,
                createdBy: photo.createdBy
            )
            try await client
                .from("place_photos")
                .upsert(payload, onConflict: "place_id,file_name")
                .execute()

            // 記錄 remoteURL（由 path 組合）
            photo.remoteURL = publicURL(for: path)
            print("照片上傳成功：\(photo.fileName)")
            return true
        } catch {
            print("照片上傳失敗「\(photo.fileName)」：\(error)")
            return false
        }
    }

    // MARK: - 刪除雲端照片

    private func deleteRemotePhoto(storagePath: String, fileName: String, placeRemoteID: UUID) async -> Bool {
        do {
            try await client.storage
                .from("place-photos")
                .remove(paths: [storagePath])

            try await client
                .from("place_photos")
                .delete()
                .eq("file_name", value: fileName)
                .eq("place_id", value: placeRemoteID.uuidString)
                .execute()

            print("雲端照片刪除成功：\(storagePath)")
            return true
        } catch {
            print("雲端照片刪除失敗：\(error)")
            return false
        }
    }

    // MARK: - 下載並快取單張照片

    func downloadAndCachePhoto(remoteURL: String, fileName: String) async -> Bool {
        guard !PlacePhotoManager.shared.hasCached(fileName: fileName) else { return true }
        guard let url = URL(string: remoteURL) else { return false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return PlacePhotoManager.shared.cachePhoto(data: data, fileName: fileName)
        } catch {
            print("照片下載失敗：\(error)")
            return false
        }
    }

    // MARK: - 重置本地快取（重新從雲端下載）

    func resetLocalPhotos(
        for placeID: UUID,
        placeType: String,
        remoteID: UUID,
        context: ModelContext
    ) async -> Bool {
        // 清除本機所有照片記錄和快取
        let descriptor = FetchDescriptor<PlacePhoto>(
            predicate: #Predicate { $0.placeID == placeID }
        )
        guard let localPhotos = try? context.fetch(descriptor) else { return false }

        for photo in localPhotos {
            PlacePhotoManager.shared.delete(fileName: photo.fileName)
            context.delete(photo)
        }
        try? context.save()

        // 從雲端重新下載
        let remotePhotos = await fetchRemotePhotoRecords(placeRemoteID: remoteID, placeType: placeType)
        guard !remotePhotos.isEmpty else { return true }

        for remotePhoto in remotePhotos {
            let url = publicURL(for: remotePhoto.storagePath)
            let success = await downloadAndCachePhoto(remoteURL: url, fileName: remotePhoto.fileName)
            if success {
                let photo = PlacePhoto(
                    placeID: placeID,
                    fileName: remotePhoto.fileName,
                    category: "",
                    sortOrder: remotePhoto.sortOrder
                )
                photo.remoteURL = url
                photo.needsUpload = false
                context.insert(photo)
            }
        }

        try? context.save()
        return true
    }
}

// MARK: - 資料結構

struct RemotePhotoRecord: Codable {
    let id: UUID
    let storagePath: String
    let fileName: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case storagePath = "storage_path"
        case fileName = "file_name"
        case sortOrder = "sort_order"
    }
}

struct PhotoPayload: Encodable {
    let placeID: UUID
    let placeType: String
    let storagePath: String
    let fileName: String
    let sortOrder: Int
    let createdBy: String

    enum CodingKeys: String, CodingKey {
        case placeID = "place_id"
        case placeType = "place_type"
        case storagePath = "storage_path"
        case fileName = "file_name"
        case sortOrder = "sort_order"
        case createdBy = "created_by"
    }
}

struct PhotoSyncResult {
    var uploaded: Int = 0
    var deleted: Int = 0
    var failed: Int = 0

    var hasFailures: Bool { failed > 0 }
    var summary: String {
        var parts: [String] = []
        if uploaded > 0 { parts.append("上傳 \(uploaded) 張") }
        if deleted > 0 { parts.append("刪除 \(deleted) 張") }
        if failed > 0 { parts.append("失敗 \(failed) 張") }
        if parts.isEmpty { return "照片已是最新狀態" }
        return parts.joined(separator: "、")
    }
}
