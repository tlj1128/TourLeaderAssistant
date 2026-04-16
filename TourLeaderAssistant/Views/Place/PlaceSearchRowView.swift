import SwiftUI
import SwiftData

struct PlaceSearchRowView: View {
    @Environment(\.modelContext) private var modelContext

    let preview: PlaceSearchPreview
    /// 是否由 NavigationLink 包裹（本機資料），決定是否自己畫箭頭
    var isNavigable: Bool
    var onDownloaded: (UUID) -> Void

    @State private var isDownloading = false
    @State private var isLocalNow: Bool

    init(preview: PlaceSearchPreview, isNavigable: Bool = false, onDownloaded: @escaping (UUID) -> Void) {
        self.preview = preview
        self.isNavigable = isNavigable
        self.onDownloaded = onDownloaded
        self._isLocalNow = State(initialValue: preview.isLocal)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 地點資訊
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if let subtitle = preview.displaySubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(preview.locationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 狀態標記
            HStack(spacing: 8) {
                badgeView

                // 只有雲端資料（非 NavigationLink）且已下載後才手動顯示箭頭
                // NavigationLink 本身會自動加箭頭，不需要手動畫
                if !isNavigable && isLocalNow {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AppSecondary"))
                }
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var badgeView: some View {
        if isDownloading {
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 52, height: 24)
        } else if isLocalNow {
            let (label, color) = badgeInfo
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
        } else {
            // 【下載】按鈕，下載後顯示箭頭提示可點
            Button {
                Task { await download() }
            } label: {
                Text("下載")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color("AppAccent"), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var badgeInfo: (String, Color) {
        if preview.localNeedsSync {
            return ("本地", Color("AppSecondary"))
        } else {
            return ("已存", .green)
        }
    }

    private func download() async {
        isDownloading = true
        let success: Bool
        switch preview.type {
        case .hotel:
            success = await SupabaseManager.shared.downloadHotel(remoteID: preview.id, context: modelContext)
        case .restaurant:
            success = await SupabaseManager.shared.downloadRestaurant(remoteID: preview.id, context: modelContext)
        case .attraction:
            success = await SupabaseManager.shared.downloadAttraction(remoteID: preview.id, context: modelContext)
        }
        isDownloading = false
        if success {
            isLocalNow = true
            onDownloaded(preview.id)
        }
    }
}
