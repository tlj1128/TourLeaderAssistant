import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct TourMemberSourceView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allDocuments: [TourDocument]

    // 是否支援 iOS 26 結構化辨識（圖片 + PDF）
    private var supportsStructuredOCR: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    // 在當前 iOS 版本下可解析的文件副檔名
    private var parseableDocExtensions: [String] {
        if supportsStructuredOCR { return ["xlsx", "docx", "pdf"] }
        return ["xlsx", "docx"]
    }

    private let imageExtensions = ["jpg", "jpeg", "png", "heic"]

    var roomingDocs: [TourDocument] {
        allDocuments.filter {
            $0.teamID == team.id &&
            $0.category == .roomingList &&
            parseableDocExtensions.contains($0.resolvedURL.pathExtension.lowercased())
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
    var guestDocs: [TourDocument] {
        allDocuments.filter {
            $0.teamID == team.id &&
            $0.category == .guestList &&
            parseableDocExtensions.contains($0.resolvedURL.pathExtension.lowercased())
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

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
    @State private var structuredResult: StructuredOCRTable? = nil
    @State private var showingStructuredPreview = false

    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    // 檔案匯入接受的型別
    private var allowedFilePickerTypes: [UTType] {
        var types: [UTType] = [
            .spreadsheet,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "xlsx") ?? .data
        ]
        if supportsStructuredOCR {
            types.append(.pdf)
            types.append(.image)
        }
        return types
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            List {
                // ── 從檔案解析 ──
                Section {
                    if hasAnyDoc {
                        ForEach(roomingDocs) { doc in
                            docRow(doc: doc, badge: "分房表")
                        }
                        ForEach(guestDocs) { doc in
                            docRow(doc: doc, badge: "團體大表")
                        }
                    }

                    // iOS 26+ 才顯示已上傳圖片
                    if supportsStructuredOCR && hasAnyImage {
                        ForEach(roomingImages) { doc in
                            imageDocRow(doc: doc, badge: "分房表")
                        }
                        ForEach(guestImages) { doc in
                            imageDocRow(doc: doc, badge: "團體大表")
                        }
                    }

                    if !hasAnyDoc && !(supportsStructuredOCR && hasAnyImage) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("尚無可解析的文件")
                                .font(.subheadline)
                                .foregroundStyle(Color(.systemGray))
                            Text(supportsStructuredOCR
                                 ? "請上傳分房表、團體大表，或 PDF / 圖片"
                                 : "請上傳分房表或團體大表")
                                .font(.caption)
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color("AppCard"))
                    }

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
                    sectionHeader(icon: "doc.fill", title: "從檔案解析")
                } footer: {
                    Text(supportsStructuredOCR
                         ? "支援 xlsx、docx、pdf、jpg、png、heic"
                         : "支援 xlsx、docx 格式（圖片 / PDF 解析需 iOS 26+）")
                        .font(.caption2)
                }

                // ── 相機與相簿（iOS 26+）──
                if supportsStructuredOCR {
                    Section {
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
                        sectionHeader(icon: "camera", title: "相機與相簿")
                    } footer: {
                        Text("拍攝表格照片自動辨識欄位，建議在光線充足處拍攝")
                            .font(.caption2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)

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

        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: allowedFilePickerTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }

        .confirmationDialog("這份文件是？", isPresented: $showingCategoryPicker, titleVisibility: .visible) {
            Button("分房表") { savePendingFile(as: .roomingList) }
            Button("團體大表") { savePendingFile(as: .guestList) }
            Button("取消", role: .cancel) { pendingFileURL = nil }
        }

        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                showingCamera = false
                parseImage(image)
            }
            .appDynamicTypeSize(textSizePreference)
        }

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
        .navigationDestination(isPresented: $showingStructuredPreview) {
            structuredPreviewDestination
        }
    }

    // MARK: - 文件列 Row

    private func docRow(doc: TourDocument, badge: String) -> some View {
        Button {
            parseDocument(doc)
        } label: {
            HStack(spacing: 12) {
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

    // MARK: - 解析

    private func parseDocument(_ doc: TourDocument) {
        let url = doc.resolvedURL
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            guard supportsStructuredOCR else {
                parseError = "PDF 解析需 iOS 26 以上"
                return
            }
            isParsing = true
            Task {
                if #available(iOS 26, *) {
                    do {
                        let result = try await TourMemberParser.recognizeStructured(fromPDF: url)
                        await MainActor.run {
                            structuredResult = result
                            isParsing = false
                            showingStructuredPreview = true
                        }
                    } catch {
                        await MainActor.run {
                            isParsing = false
                            parseError = error.localizedDescription
                        }
                    }
                }
            }
            return
        }

        if imageExtensions.contains(ext) {
            guard let image = UIImage(contentsOfFile: url.path) else {
                parseError = "無法讀取圖片"
                return
            }
            parseImage(image)
            return
        }

        // xlsx / docx
        isParsing = true
        Task {
            do {
                let tables = try TourMemberParser.extractTables(from: url)
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

    private func parseImage(_ image: UIImage) {
        guard supportsStructuredOCR else {
            parseError = "圖片解析需 iOS 26 以上"
            return
        }
        isParsing = true
        Task {
            if #available(iOS 26, *) {
                do {
                    let result = try await TourMemberParser.recognizeStructured(from: image)
                    await MainActor.run {
                        structuredResult = result
                        isParsing = false
                        showingStructuredPreview = true
                    }
                } catch {
                    await MainActor.run {
                        isParsing = false
                        parseError = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - 上傳文件

    private func handleFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

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
    private var structuredPreviewDestination: some View {
        if let result = structuredResult {
            TourMemberStructuredPreviewView(
                team: team,
                result: result
            ) { members in
                parsedMembers = members
                showingStructuredPreview = false
                showingPreview = true
            }
        } else {
            EmptyView()
        }
    }
}
