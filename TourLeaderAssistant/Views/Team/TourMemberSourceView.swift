import SwiftUI
import SwiftData
import PhotosUI

struct TourMemberSourceView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allDocuments: [TourDocument]

    // 已上傳的分房表 / 大表
    private let supportedExtensions = ["xlsx", "docx", "pdf"]

    var roomingDocs: [TourDocument] {
        allDocuments.filter {
            $0.teamID == team.id &&
            $0.category == .roomingList &&
            supportedExtensions.contains($0.resolvedURL.pathExtension.lowercased())
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
    var guestDocs: [TourDocument] {
        allDocuments.filter {
            $0.teamID == team.id &&
            $0.category == .guestList &&
            supportedExtensions.contains($0.resolvedURL.pathExtension.lowercased())
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
    private let imageExtensions = ["jpg", "jpeg", "png", "heic"]

    var roomingImages: [TourDocument] {
        allDocuments.filter {
            $0.teamID == team.id &&
            $0.category == .roomingList &&
            imageExtensions.contains($0.resolvedURL.pathExtension.lowercased())
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
    var guestImages: [TourDocument] {
        allDocuments.filter {
            $0.teamID == team.id &&
            $0.category == .guestList &&
            imageExtensions.contains($0.resolvedURL.pathExtension.lowercased())
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
    var hasAnyImage: Bool { !roomingImages.isEmpty || !guestImages.isEmpty }
    var hasAnyDoc: Bool { !roomingDocs.isEmpty || !guestDocs.isEmpty }

    // 上傳相關
    @State private var showingFilePicker = false
    @State private var showingCategoryPicker = false
    @State private var pendingFileURL: URL? = nil

    // 圖片相關
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    // 解析相關
    @State private var isParsing = false
    @State private var parseError: String? = nil
    @State private var parsedMembers: [ParsedMember] = []
    @State private var showingPreview = false
    @State private var rawTables: [RawTable] = []
    @State private var showingRawPreview = false
    @State private var showingOCRMapping = false
    @State private var ocrLines: [String] = []

    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                // ── 從文件解析 ──
                Section {
                    if hasAnyDoc {
                        // 分房表（排除 PDF）
                        ForEach(roomingDocs.filter { $0.resolvedURL.pathExtension.lowercased() != "pdf" }) { doc in
                            docRow(doc: doc, badge: "分房表")
                        }
                        // 團體大表（排除 PDF）
                        ForEach(guestDocs.filter { $0.resolvedURL.pathExtension.lowercased() != "pdf" }) { doc in
                            docRow(doc: doc, badge: "團體大表")
                        }
                    } else {
                        // 沒有文件：提示上傳
                        VStack(alignment: .leading, spacing: 8) {
                            Text("尚無可解析的文件")
                                .font(.subheadline)
                                .foregroundStyle(Color(.systemGray))
                            Text("請上傳分房表或團體大表")
                                .font(.caption)
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color("AppCard"))
                    }

                    // 上傳按鈕（永遠顯示）
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color("AppAccent"))
                            Text("上傳文件")
                                .foregroundStyle(Color("AppAccent"))
                                .font(.subheadline)
                        }
                    }
                    .listRowBackground(Color("AppCard"))

                } header: {
                    sectionHeader(icon: "doc.fill", title: "從文件解析")
                } footer: {
                    Text("支援 xlsx、docx 格式（PDF 暫不支援自動解析，請用截圖方式讀取）")
                        .font(.caption2)
                }

                // ── 從圖片解析 ──
                        Section {
                            // 已上傳的圖片
                            if !roomingImages.isEmpty || !guestImages.isEmpty {
                                ForEach(roomingImages) { doc in
                                    imageDocRow(doc: doc, badge: "分房表")
                                }
                                ForEach(guestImages) { doc in
                                    imageDocRow(doc: doc, badge: "團體大表")
                                }
                            }

                            // 從相簿
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title3)
                                .foregroundStyle(Color(hex: "2DB8A8"))
                                .frame(width: 32)
                            Text("從相簿選取")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color("AppCard"))

                    // 相機
                    Button {
                        showingCamera = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundStyle(Color(hex: "2DB8A8"))
                                .frame(width: 32)
                            Text("用相機拍攝")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color("AppCard"))

                } header: {
                    sectionHeader(icon: "photo", title: "從圖片解析")
                } footer: {
                    Text("支援 jpg、png、heic 格式，建議在光線充足處拍攝")
                        .font(.caption2)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

            // 解析中 overlay
            if isParsing {
                Color.black.opacity(0.3).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("解析中…")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .padding(32)
                .background(Color(.systemGray).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationTitle("解析名單")
        .navigationBarTitleDisplayMode(.inline)

        // 文件選取
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.spreadsheet, .pdf,
                                  .init(filenameExtension: "docx")!,
                                  .init(filenameExtension: "xlsx")!],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }

        // 選完類別後儲存
        .confirmationDialog("這份文件是？", isPresented: $showingCategoryPicker, titleVisibility: .visible) {
            Button("分房表") { savePendingFile(as: .roomingList) }
            Button("團體大表") { savePendingFile(as: .guestList) }
            Button("取消", role: .cancel) { pendingFileURL = nil }
        }

        // 相機
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                showingCamera = false
                parseImage(image)
            }
            .appDynamicTypeSize(textSizePreference)
        }

        // 相簿選取後解析
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    parseImage(image)
                }
                selectedPhotoItem = nil
            }
        }

        // 解析錯誤
        .alert("解析失敗", isPresented: .constant(parseError != nil)) {
            Button("確定") { parseError = nil }
        } message: {
            Text(parseError ?? "")
        }

        .navigationDestination(isPresented: $showingPreview) {
            TourMemberPreviewView(
                team: team,
                parsedMembers: parsedMembers
            ) {
                showingPreview = false
            }
        }
        .navigationDestination(isPresented: $showingRawPreview) {
            rawPreviewDestination
        }
        .navigationDestination(isPresented: $showingOCRMapping) {
            ocrMappingDestination
        }
    }

    // MARK: - 文件列 Row

    private func docRow(doc: TourDocument, badge: String) -> some View {
        Button {
            parseDocument(doc)
        } label: {
            HStack(spacing: 12) {
                // 副檔名標籤
                Text(doc.resolvedURL.pathExtension.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .frame(width: 46)
                    .background(extensionColor(doc.resolvedURL.pathExtension))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(doc.fileName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(badge)
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.vertical, 3)
        }
        .listRowBackground(Color("AppCard"))
    }
    
    private func imageDocRow(doc: TourDocument, badge: String) -> some View {
            Button {
                guard let image = UIImage(contentsOfFile: doc.resolvedURL.path) else {
                    parseError = "無法讀取圖片"
                    return
                }
                parseImage(image)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(Color(hex: "2DB8A8"))
                        .frame(width: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(doc.fileName)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        Text(badge)
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray3))
                }
                .padding(.vertical, 3)
            }
            .listRowBackground(Color("AppCard"))
        }

    // MARK: - 解析文件

    private func parseDocument(_ doc: TourDocument) {
        isParsing = true
        Task {
            do {
                let tables = try TourMemberParser.extractTables(from: doc.resolvedURL)
                await MainActor.run {
                    rawTables = tables
                    isParsing = false
                    showingRawPreview = true
                }
            } catch {
                await MainActor.run {
                    isParsing = false
                    parseError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 解析圖片

    private func parseImage(_ image: UIImage) {
        isParsing = true
        Task {
            do {
                let tables = try await TourMemberParser.extractTables(from: image)
                let lines = tables.flatMap { $0.rows.map { $0.joined(separator: " ") } }
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                await MainActor.run {
                    ocrLines = lines
                    isParsing = false
                    showingOCRMapping = true
                }
            } catch {
                await MainActor.run {
                    isParsing = false
                    parseError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 上傳文件

    private func handleFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        // 先暫存 URL（需要複製到 App 沙盒）
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.copyItem(at: url, to: tempURL)

        pendingFileURL = tempURL
        showingCategoryPicker = true
    }

    private func savePendingFile(as category: DocumentCategory) {
        guard let tempURL = pendingFileURL else { return }

        do {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let teamDir = docsDir.appendingPathComponent(team.id.uuidString)
            try FileManager.default.createDirectory(at: teamDir, withIntermediateDirectories: true)

            let destURL = teamDir.appendingPathComponent(tempURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: tempURL, to: destURL)
            try? FileManager.default.removeItem(at: tempURL)

            let doc = TourDocument(
                teamID: team.id,
                category: category,
                fileName: tempURL.lastPathComponent,
                fileURL: destURL
            )
            modelContext.insert(doc)

            // 存完直接解析
            parseDocument(doc)

        } catch {
            parseError = "文件儲存失敗：\(error.localizedDescription)"
            pendingFileURL = nil
        }
    }

    // MARK: - 輔助


        private func extensionColor(_ ext: String) -> Color {
        switch ext.lowercased() {
        case "pdf": return Color(hex: "E8650A")
        case "doc", "docx": return Color(hex: "5B8CDB")
        case "xls", "xlsx": return Color(hex: "2DB8A8")
        default: return Color(.systemGray3)
        }
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Color("AppAccent"))
            Text(title)
                .font(.footnote).fontWeight(.semibold)
                .foregroundStyle(Color(.systemGray))
        }
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private var rawPreviewDestination: some View {
        TourMemberRawPreviewView(
            team: team,
            tables: rawTables
        ) { members in
            parsedMembers = members
            showingRawPreview = false
            showingPreview = true
        }
    }

    @ViewBuilder
    private var ocrMappingDestination: some View {
        TourMemberOCRMappingView(
            team: team,
            ocrLines: ocrLines
        ) { members in
            parsedMembers = members
            showingOCRMapping = false
            showingPreview = true
        }
    }
}
