import SwiftUI
import Supabase

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - 表單狀態
    @State private var selectedCategory: FeedbackCategory = .suggestion
    @State private var title: String = ""
    @State private var content: String = ""

    // MARK: - UI 狀態
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let contentLimit = 500
    private let contentMinimum = 10

    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        content.trimmingCharacters(in: .whitespaces).count >= contentMinimum
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 類型
                Section {
                    Picker("類型", selection: $selectedCategory) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                } header: {
                    Text("回饋類型")
                }

                // MARK: - 標題
                Section {
                    TextField("簡短描述問題或建議", text: $title)
                } header: {
                    Text("標題")
                }

                // MARK: - 詳細說明
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

                // MARK: - 送出
                Section {
                    Button {
                        Task { await submitFeedback() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isSubmitting ? "送出中…" : "送出回饋")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || isSubmitting)
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

    // MARK: - 送出邏輯
    private func submitFeedback() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let deviceID = KeychainManager.deviceUUID

        let payload = FeedbackPayload(
            deviceId: deviceID,
            category: selectedCategory.rawValue,
            title: title.trimmingCharacters(in: .whitespaces),
            content: content.trimmingCharacters(in: .whitespaces),
            appVersion: appVersion
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
}

// MARK: - FeedbackCategory

enum FeedbackCategory: String, CaseIterable {
    case suggestion = "功能建議"
    case uiIssue = "介面操作問題"
    case syncIssue = "同步問題"
    case crash = "閃退或當機"
    case other = "其他"

    var displayName: String { rawValue }
}

// MARK: - FeedbackPayload

private struct FeedbackPayload: Encodable {
    let deviceId: String
    let category: String
    let title: String
    let content: String
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case category
        case title
        case content
        case appVersion = "app_version"
    }
}
