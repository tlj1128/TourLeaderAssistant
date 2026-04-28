import SwiftUI
import PhotosUI
import Supabase

// MARK: - FeedbackCategory

enum FeedbackCategory: String, CaseIterable {
    case suggestion = "功能建議"
    case uiIssue = "介面操作問題"
    case syncIssue = "同步問題"
    case crash = "閃退或當機"
    case other = "其他"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .suggestion: return "lightbulb"
        case .uiIssue:   return "hand.tap"
        case .syncIssue: return "arrow.triangle.2.circlepath"
        case .crash:     return "exclamationmark.triangle"
        case .other:     return "ellipsis.bubble"
        }
    }
}

// MARK: - FeedbackView

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: 步驟控制
    @State private var currentStep = 1

    // MARK: Step 1
    @State private var selectedCategory: FeedbackCategory = .suggestion
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var screenshots: [UIImage] = []

    // MARK: Step 2
    @State private var email: String = ""

    // MARK: UI 狀態
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let contentLimit = 500
    private let contentMinimum = 10
    private let maxScreenshots = 3

    // MARK: 系統資訊
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
    private var iosVersion: String {
        UIDevice.current.systemVersion
    }
    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { ptr in
            ptr.compactMap { $0 == 0 ? nil : String(UnicodeScalar($0)) }.joined()
        }
    }

    private var isStep1Valid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        content.trimmingCharacters(in: .whitespaces).count >= contentMinimum
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentStep == 1 {
                    step1View
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    step2View
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                }
            }
            .navigationTitle("意見回饋")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("感謝你的回饋！", isPresented: $showSuccessAlert) {
                Button("好") { dismiss() }
            } message: {
                Text("我會仔細閱讀並持續改善領隊助手，謝謝！")
            }
            .alert("送出失敗", isPresented: $showErrorAlert) {
                Button("確定") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Step 1：填寫內容

    private var step1View: some View {
        Form {
            Section("回饋類型") {
                Picker("類型", selection: $selectedCategory) {
                    ForEach(FeedbackCategory.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("標題") {
                TextField("簡短描述問題或建議", text: $title)
            }

            Section {
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: Binding(
                        get: { content },
                        set: { content = String($0.prefix(contentLimit)) }
                    ))
                    .frame(minHeight: 120)

                    Text("\(content.count)/\(contentLimit)")
                        .font(.caption)
                        .foregroundStyle(content.count < contentMinimum ? Color.orange : Color.secondary)
                        .padding(.bottom, 4)
                        .padding(.trailing, 4)
                }
                if content.count < contentMinimum && !content.isEmpty {
                    Text("至少需要 \(contentMinimum) 個字")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            } header: {
                Text("詳細說明")
            }

            Section {
                if !screenshots.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(screenshots.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: screenshots[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Button {
                                        screenshots.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(Color.white, Color(.systemGray))
                                            .font(.title3)
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if screenshots.count < maxScreenshots {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: maxScreenshots - screenshots.count,
                        matching: .images
                    ) {
                        Label(
                            screenshots.isEmpty ? "附加截圖（最多 \(maxScreenshots) 張）" : "繼續新增截圖",
                            systemImage: "photo.badge.plus"
                        )
                    }
                    .onChange(of: pickerItems) { _, newItems in
                        Task {
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data),
                                   screenshots.count < maxScreenshots {
                                    screenshots.append(image)
                                }
                            }
                            pickerItems = []
                        }
                    }
                }
            } header: {
                Text("附加截圖（選填）")
            } footer: {
                Text("附上畫面截圖有助於更快理解問題。")
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        withAnimation { currentStep = 2 }
                    } label: {
                        HStack(spacing: 4) {
                            Text("下一步")
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.right")
                        }
                    }
                    .disabled(!isStep1Valid)
                }
            }
        }
    }

    // MARK: - Step 2：確認送出

    private var step2View: some View {
        Form {
            Section("回饋內容確認") {
                LabeledContent("類型", value: selectedCategory.displayName)
                LabeledContent("標題", value: title)
                VStack(alignment: .leading, spacing: 4) {
                    Text("說明")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(content)
                        .font(.subheadline)
                }
                .padding(.vertical, 2)

                if !screenshots.isEmpty {
                    LabeledContent("截圖") {
                        Text("\(screenshots.count) 張")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                LabeledContent("App 版本", value: appVersion)
                LabeledContent("iOS 版本", value: iosVersion)
                LabeledContent("裝置型號", value: deviceModel)
            } header: {
                Text("系統資訊（自動帶入）")
            } footer: {
                Text("這些資訊將一併送出，有助於重現問題。")
            }

            Section {
                TextField("your@email.com", text: $email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Email（選填）")
            } footer: {
                Text("填寫後開發者可直接回覆你，不填也完全沒問題。")
            }

            Section {
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一步")
                    }
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { currentStep = 1 }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSubmitting ? "送出中…" : "送出回饋")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isSubmitting {
                            Task { await submitFeedback() }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 送出邏輯

    private func submitFeedback() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let feedbackID = UUID()

        // 1. 上傳截圖
        var screenshotPaths: [String] = []
        for (index, image) in screenshots.enumerated() {
            if let path = await uploadScreenshot(image: image, feedbackID: feedbackID, index: index) {
                screenshotPaths.append(path)
            }
        }

        // 2. 送出回饋
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let payload = FeedbackPayload(
            id: feedbackID,
            deviceId: KeychainManager.deviceUUID,
            category: selectedCategory.rawValue,
            title: title.trimmingCharacters(in: .whitespaces),
            content: content.trimmingCharacters(in: .whitespaces),
            appVersion: appVersion,
            iosVersion: iosVersion,
            deviceModel: deviceModel,
            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
            screenshots: screenshotPaths
        )

        do {
            try await SupabaseManager.shared.client
                .from("feedback")
                .insert(payload)
                .execute()
            showSuccessAlert = true
        } catch {
            errorMessage = "請確認網路連線後再試一次。"
            showErrorAlert = true
        }
    }

    // MARK: - 截圖上傳

    private func uploadScreenshot(image: UIImage, feedbackID: UUID, index: Int) async -> String? {
        // 壓縮：長邊最大 1080px，JPEG 0.7
        let resized = resizeImage(image, maxDimension: 1080)
        guard let data = resized.jpegData(compressionQuality: 0.7) else { return nil }

        let fileName = "\(index + 1).jpg"
        let path = "\(feedbackID.uuidString)/\(fileName)"

        do {
            try await SupabaseManager.shared.client.storage
                .from("feedback-screenshots")
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
            return path
        } catch {
            print("截圖上傳失敗 \(fileName)：\(error)")
            return nil
        }
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - FeedbackPayload

private struct FeedbackPayload: Encodable {
    let id: UUID
    let deviceId: String
    let category: String
    let title: String
    let content: String
    let appVersion: String
    let iosVersion: String
    let deviceModel: String
    let email: String?
    let screenshots: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case category
        case title
        case content
        case appVersion = "app_version"
        case iosVersion = "ios_version"
        case deviceModel = "device_model"
        case email
        case screenshots
    }
}
