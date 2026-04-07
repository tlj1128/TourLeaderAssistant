import SwiftUI
import SwiftData
import QuickLook

struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allDocuments: [TourDocument]
    @State private var showingPicker = false
    @State private var selectedCategory: DocumentCategory = .other
    @State private var previewURL: URL? = nil
    @State private var showingCategoryPicker = false

    var documents: [TourDocument] {
        allDocuments
            .filter { $0.teamID == team.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var groupedDocuments: [(DocumentCategory, [TourDocument])] {
        let grouped = Dictionary(grouping: documents) { $0.category }
        return DocumentCategory.allCases
            .compactMap { cat in
                guard let docs = grouped[cat], !docs.isEmpty else { return nil }
                return (cat, docs)
            }
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if documents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.title)
                        .foregroundStyle(Color("AppAccent").opacity(0.4))
                    Text("尚無文件")
                        .font(.title3).fontWeight(.semibold)
                    Text("點右上角 ＋ 上傳文件")
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemGray))
                }
            } else {
                List {
                    ForEach(groupedDocuments, id: \.0) { category, docs in
                        Section {
                            ForEach(docs) { doc in
                                DocumentRowView(doc: doc)
                                    .contentShape(Rectangle())
                                    .listRowBackground(Color("AppCard"))
                                    .onTapGesture { previewURL = doc.fileURL }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteDocument(doc)
                                        } label: {
                                            Label("刪除", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            shareDocument(doc)
                                        } label: {
                                            Label("分享", systemImage: "square.and.arrow.up")
                                        }
                                        .tint(Color(hex: "5B8CDB"))
                                    }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundStyle(Color("AppAccent"))
                                Text(category.displayName)
                                    .font(.footnote).fontWeight(.semibold)
                                    .foregroundStyle(Color(.systemGray))
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("資料中心")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCategoryPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color("AppAccent"))
                }
            }
        }
        .confirmationDialog("選擇文件類別", isPresented: $showingCategoryPicker, titleVisibility: .visible) {
            ForEach(DocumentCategory.allCases, id: \.self) { cat in
                Button(cat.displayName) {
                    selectedCategory = cat
                    showingPicker = true
                }
            }
            Button("取消", role: .cancel) {}
        }
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.pdf, .text, .spreadsheet, .presentation, .image, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .quickLookPreview($previewURL)
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let teamDir = docsDir.appendingPathComponent(team.id.uuidString)
            try FileManager.default.createDirectory(at: teamDir, withIntermediateDirectories: true)

            let destURL = teamDir.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)

            let doc = TourDocument(
                teamID: team.id,
                category: selectedCategory,
                fileName: url.lastPathComponent,
                fileURL: destURL
            )
            modelContext.insert(doc)
        } catch {
            print("文件匯入錯誤：\(error)")
        }
    }

    private func deleteDocument(_ doc: TourDocument) {
        try? FileManager.default.removeItem(at: doc.fileURL)
        modelContext.delete(doc)
    }

    private func shareDocument(_ doc: TourDocument) {
        let av = UIActivityViewController(activityItems: [doc.fileURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - DocumentRowView

struct DocumentRowView: View {
    let doc: TourDocument

    var fileExtension: String {
        doc.fileURL.pathExtension.uppercased()
    }

    var extensionColor: Color {
        switch doc.fileURL.pathExtension.lowercased() {
        case "pdf": return Color(hex: "E8650A")
        case "doc", "docx": return Color(hex: "5B8CDB")
        case "xls", "xlsx": return Color(hex: "2DB8A8")
        case "ppt", "pptx": return Color(hex: "E8650A")
        default: return Color(.systemGray3)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 副檔名標籤
            Text(fileExtension.isEmpty ? "FILE" : fileExtension)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(width: 46)
                .background(extensionColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(doc.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(doc.createdAt.formatted(date: .abbreviated, time: .omitted))
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
}
