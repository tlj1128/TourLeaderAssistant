import SwiftUI
import SwiftData

// MARK: - 主頁

struct iCloudBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("textSizePreference") private var textSizePreference = "standard"
    @AppStorage("lastBackupDate") private var lastBackupDateStr = ""

    @State private var showBackupPreview = false
    @State private var showRestoreList = false
    @State private var backupCount = 0
    @State private var preview: BackupPreview? = nil

    var lastBackupText: String {
        guard !lastBackupDateStr.isEmpty,
              let date = ISO8601DateFormatter().date(from: lastBackupDateStr) else {
            return "尚未備份"
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }

    var statusText: String {
        if backupCount == 0 {
            guard let preview = preview else { return "載入中..." }
            var parts: [String] = []
            if preview.teamCount > 0 { parts.append("\(preview.teamCount) 個團體") }
            if preview.expenseCount > 0 { parts.append("\(preview.expenseCount) 筆帳務") }
            if preview.journalCount > 0 { parts.append("\(preview.journalCount) 筆日誌") }
            if parts.isEmpty { return "尚無資料" }
            return "尚未備份｜" + parts.joined(separator: "、")
        } else {
            return "共 \(backupCount) 份備份"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: 狀態區塊
                        VStack(spacing: 6) {
                            Image(systemName: backupCount > 0 ? "icloud.fill" : "icloud")
                                .font(.system(size: 48))
                                .foregroundStyle(backupCount > 0 ? Color("AppAccent") : .secondary)
                            Text("iCloud 備份")
                                .font(.title2).fontWeight(.semibold)
                            Text("上次備份：\(lastBackupText)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(backupCount == 0 ? .orange : .secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 24)

                        // MARK: 備份與還原
                        VStack(spacing: 12) {
                            Button {
                                showBackupPreview = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.to.line.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color("AppAccent"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("立即備份")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text("將資料備份至 iCloud")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color("AppCard"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            Button {
                                showRestoreList = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.to.line.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("從備份還原")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(backupCount == 0 ? "尚無備份" : "選擇備份版本還原資料")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color("AppCard"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .disabled(backupCount == 0)
                            .opacity(backupCount == 0 ? 0.5 : 1)
                        }
                        .padding(.horizontal)

                        // MARK: 隱私說明
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield")
                                    .foregroundStyle(Color("AppAccent"))
                                Text("隱私說明")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(Color("AppAccent"))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                privacyRow(icon: "person.icloud", text: "備份儲存在您的個人 iCloud 空間")
                                privacyRow(icon: "server.rack", text: "資料不會上傳至任何第三方伺服器")
                                privacyRow(icon: "lock", text: "備份檔案僅限本 App 存取")
                                privacyRow(icon: "checkmark.shield", text: "端對端加密傳輸")
                            }
                        }
                        .padding()
                        .background(Color("AppCard"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        Text("備份檔案會保留最近 5 個版本")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("iCloud 備份")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refresh() }
            .sheet(isPresented: $showBackupPreview, onDismiss: { refresh() }) {
                BackupPreviewView(onBackupCompleted: { date in
                    lastBackupDateStr = ISO8601DateFormatter().string(from: date)
                })
                .appDynamicTypeSize(textSizePreference)
            }
            .sheet(isPresented: $showRestoreList, onDismiss: { refresh() }) {
                BackupRestoreListView()
                    .appDynamicTypeSize(textSizePreference)
            }
        }
    }

    private func refresh() {
        backupCount = BackupManager.shared.listBackups().count
        preview = BackupManager.shared.previewBackup(context: modelContext)
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 備份確認頁

private struct BackupPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onBackupCompleted: (Date) -> Void

    @State private var preview: BackupPreview? = nil
    @State private var isBackingUp = false
    @State private var showSuccess = false
    @State private var backupResult: BackupFileInfo? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                if isBackingUp {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("正在備份...").font(.headline)
                        Text("請勿關閉 App")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else if showSuccess, let result = backupResult {
                    // 備份完成摘要
                    ScrollView {
                        VStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(.green)
                                Text("備份完成")
                                    .font(.title2).fontWeight(.semibold)
                            }
                            .padding(.top, 32)

                            VStack(spacing: 0) {
                                summaryRow(icon: "airplane", text: "團體資料", value: "\(result.teamCount) 個")
                                Divider().padding(.leading, 44)
                                summaryRow(icon: "yensign.circle", text: "帳務紀錄", value: "\(result.expenseCount) 筆")
                                Divider().padding(.leading, 44)
                                summaryRow(icon: "book", text: "每日日誌", value: "\(result.journalCount) 筆")
                                Divider().padding(.leading, 44)
                                summaryRow(icon: "tag", text: "自訂類型", value: "\(result.customTypeCount) 個")
                                Divider().padding(.leading, 44)
                                summaryRow(icon: "building.2", text: "自訂城市", value: "\(result.cityCount) 個")
                                Divider().padding(.leading, 44)
                                summaryRow(icon: "mappin", text: "本機地點", value: "\(result.placeCount) 個")
                                if result.photoCount > 0 {
                                    Divider().padding(.leading, 44)
                                    summaryRow(icon: "photo", text: "地點照片", value: "\(result.photoCount) 張")
                                }
                                Divider().padding(.leading, 44)
                                summaryRow(icon: "doc", text: "檔案大小", value: result.fileSizeString)
                            }
                            .background(Color("AppCard"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                            Button("關閉") { dismiss() }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("AppAccent"))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                                .padding(.bottom, 24)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.up.to.line.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Color("AppAccent"))
                                Text("將備份以下資料到 iCloud")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.top, 24)

                            if let preview = preview {
                                VStack(spacing: 0) {
                                    previewRow(icon: "airplane", text: "團體資料", value: "\(preview.teamCount) 個")
                                    Divider().padding(.leading, 44)
                                    previewRow(icon: "yensign.circle", text: "帳務紀錄", value: "\(preview.expenseCount) 筆")
                                    Divider().padding(.leading, 44)
                                    previewRow(icon: "book", text: "每日日誌", value: "\(preview.journalCount) 筆")
                                    Divider().padding(.leading, 44)
                                    previewRow(icon: "tag", text: "自訂類型", value: "\(preview.customTypeCount) 個")
                                    Divider().padding(.leading, 44)
                                    previewRow(icon: "building.2", text: "自訂城市", value: "\(preview.cityCount) 個")
                                    Divider().padding(.leading, 44)
                                    previewRow(icon: "mappin", text: "本機地點", value: "\(preview.placeCount) 個")
                                    if preview.photoCount > 0 {
                                        Divider().padding(.leading, 44)
                                        previewRow(icon: "photo", text: "地點照片", value: "\(preview.photoCount) 張（約 \(preview.photoSizeString)）")
                                    }
                                }
                                .background(Color("AppCard"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                    Text("注意事項")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                }
                                Text("• 備份過程中請勿切換 App 或鎖定螢幕")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("• 建議在 Wi-Fi 環境下進行")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                            if let error = errorMessage {
                                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
                            }

                            Button {
                                startBackup()
                            } label: {
                                Text("開始備份")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color("AppAccent"))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("準備備份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isBackingUp && !showSuccess {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
            }
            .onAppear {
                preview = BackupManager.shared.previewBackup(context: modelContext)
            }
        }
    }

    private func startBackup() {
        isBackingUp = true
        errorMessage = nil
        Task {
            do {
                let result = try await BackupManager.shared.createBackup(context: modelContext)
                await MainActor.run {
                    isBackingUp = false
                    showSuccess = true
                    backupResult = result
                    onBackupCompleted(result.createdAt)
                }
            } catch {
                await MainActor.run {
                    isBackingUp = false
                    errorMessage = "備份失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func summaryRow(icon: String, text: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color("AppAccent"))
                .frame(width: 24)
            Text(text).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func previewRow(icon: String, text: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color("AppAccent"))
                .frame(width: 24)
            Text(text).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - 還原列表頁

private struct BackupRestoreListView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    @State private var backups: [BackupFileInfo] = []
    @State private var selectedBackup: BackupFileInfo? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                if backups.isEmpty {
                    ContentUnavailableView(
                        "尚無備份",
                        systemImage: "icloud.slash",
                        description: Text("請先建立備份")
                    )
                } else {
                    List {
                        Section {
                            ForEach(backups) { backup in
                                Button {
                                    selectedBackup = backup
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "doc.zipper")
                                            .font(.title2)
                                            .foregroundStyle(Color("AppAccent"))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(backup.formattedDate)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text("\(backup.deviceModel) • v\(backup.appVersion)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("\(backup.teamCount) 個團體・\(backup.journalCount) 筆日誌・\(backup.photoCount) 張照片")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(backup.fileSizeString)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteBackup(backup)
                                    } label: {
                                        Label("刪除", systemImage: "trash")
                                    }
                                }
                            }
                        } footer: {
                            Text("備份檔案會保留最近 5 個版本，左滑可刪除單份備份")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("從 iCloud 還原")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .onAppear {
                backups = BackupManager.shared.listBackups()
            }
            .sheet(item: $selectedBackup) { backup in
                BackupRestoreConfirmView(backup: backup, onRestoreCompleted: {
                    dismiss()
                })
                .appDynamicTypeSize(textSizePreference)
            }
        }
    }

    private func deleteBackup(_ backup: BackupFileInfo) {
        BackupManager.shared.deleteBackup(backup)
        backups = BackupManager.shared.listBackups()
    }
}

// MARK: - 確認還原頁

private struct BackupRestoreConfirmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let backup: BackupFileInfo
    let onRestoreCompleted: () -> Void

    @State private var isRestoring = false
    @State private var restoreResult: RestoreResult? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()

                if isRestoring {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("正在還原備份...").font(.headline)
                        Text("請勿關閉 App，還原完成後將自動重新整理")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if let result = restoreResult {
                    // 還原完成摘要
                    ScrollView {
                        VStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(.green)
                                Text("還原完成！")
                                    .font(.title2).fontWeight(.semibold)
                            }
                            .padding(.top, 32)

                            VStack(spacing: 0) {
                                restoreSummaryRow(icon: "airplane", text: "團體資料", value: "\(result.teamCount) 個")
                                Divider().padding(.leading, 44)
                                restoreSummaryRow(icon: "yensign.circle", text: "帳務紀錄", value: "\(result.expenseCount) 筆")
                                Divider().padding(.leading, 44)
                                restoreSummaryRow(icon: "book", text: "每日日誌", value: "\(result.journalCount) 筆")
                                Divider().padding(.leading, 44)
                                restoreSummaryRow(icon: "tag", text: "自訂類型", value: "\(result.customTypeCount) 個")
                                Divider().padding(.leading, 44)
                                restoreSummaryRow(icon: "building.2", text: "自訂城市", value: "\(result.cityCount) 個")
                                Divider().padding(.leading, 44)
                                restoreSummaryRow(icon: "mappin", text: "本機地點", value: "\(result.placeCount) 個")
                                if result.photoCount > 0 {
                                    Divider().padding(.leading, 44)
                                    restoreSummaryRow(icon: "photo", text: "地點照片", value: "\(result.photoCount) 張")
                                }
                                Divider().padding(.leading, 44)
                                restoreSummaryRow(icon: "doc", text: "檔案大小", value: result.fileSizeString)
                                Divider().padding(.leading, 44)
                                restoreSummaryRow(icon: "clock", text: "耗時", value: "\(result.elapsedSeconds) 秒")
                            }
                            .background(Color("AppCard"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                            Text("來源：\(result.sourceDateStr) 備份")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("完成") { onRestoreCompleted() }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("AppAccent"))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                                .padding(.bottom, 24)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.orange)
                                .padding(.top, 24)

                            Text("確認還原")
                                .font(.title2).fontWeight(.semibold)

                            // 將被刪除
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                    Text("以下資料將被刪除")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                }
                                Text("現有的所有團體、帳務、日誌、地點等資料")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                            Image(systemName: "arrow.down")
                                .foregroundStyle(.secondary)

                            // 將還原為
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.to.line")
                                        .foregroundStyle(.green)
                                    Text("將還原為")
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    restoreRow(text: "備份日期：\(backup.formattedDate)")
                                    restoreRow(text: "\(backup.teamCount) 個團體")
                                    restoreRow(text: "\(backup.expenseCount) 筆帳務")
                                    restoreRow(text: "\(backup.journalCount) 筆日誌")
                                    if backup.photoCount > 0 {
                                        restoreRow(text: "\(backup.photoCount) 張地點照片")
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("此操作無法復原！")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            }

                            if let error = errorMessage {
                                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
                            }

                            HStack(spacing: 12) {
                                Button("取消") { dismiss() }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color("AppCard"))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))

                                Button {
                                    startRestore()
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("刪除並還原")
                                        Image(systemName: "exclamationmark.circle.fill")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("確認還原")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isRestoring {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
            }
        }
    }

    private func startRestore() {
        isRestoring = true
        errorMessage = nil
        Task {
            do {
                let result = try await BackupManager.shared.restore(from: backup, context: modelContext)
                await MainActor.run {
                    isRestoring = false
                    restoreResult = result
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    errorMessage = "還原失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func restoreSummaryRow(icon: String, text: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(text).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func restoreRow(text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green.opacity(0.6))
                .frame(width: 6, height: 6)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
