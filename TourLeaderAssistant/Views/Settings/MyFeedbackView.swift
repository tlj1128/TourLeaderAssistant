import SwiftUI
import Supabase

struct MyFeedbackView: View {
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    @State private var feedbacks: [RemoteFeedback] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color("AppCard"))
            } else if feedbacks.isEmpty {
                ContentUnavailableView(
                    "尚無回饋紀錄",
                    systemImage: "envelope",
                    description: Text("你送出的回饋會顯示在這裡")
                )
                .listRowBackground(Color("AppCard"))
            } else {
                ForEach(feedbacks) { feedback in
                    NavigationLink(destination: FeedbackDetailView(feedback: feedback)) {
                        FeedbackRowView(feedback: feedback)
                    }
                    .listRowBackground(Color("AppCard"))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
        .navigationTitle("我的回饋")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFeedbacks() }
        .refreshable { await loadFeedbacks() }
        .alert("載入失敗", isPresented: .constant(errorMessage != nil)) {
            Button("確定") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadFeedbacks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let deviceID = KeychainManager.deviceUUID
            let results: [RemoteFeedback] = try await SupabaseManager.shared.client
                .from("feedback")
                .select("id, category, title, content, app_version, ios_version, device_model, email, screenshots, status, developer_reply, created_at")
                .eq("device_id", value: deviceID)
                .order("created_at", ascending: false)
                .execute()
                .value
            feedbacks = results
        } catch {
            errorMessage = "請確認網路連線後再試一次。"
        }
    }
}

// MARK: - FeedbackRowView

private struct FeedbackRowView: View {
    let feedback: RemoteFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(feedback.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                FeedbackStatusBadge(status: feedback.status)
            }
            Text(feedback.category)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(feedback.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - FeedbackDetailView

struct FeedbackDetailView: View {
    let feedback: RemoteFeedback

    var body: some View {
        List {
            Section("回饋內容") {
                LabeledContent("類型", value: feedback.category)
                LabeledContent("標題", value: feedback.title)
                VStack(alignment: .leading, spacing: 4) {
                    Text("說明")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(feedback.content)
                        .font(.subheadline)
                }
                .padding(.vertical, 2)
                LabeledContent("送出時間") {
                    Text(feedback.createdAt, style: .date)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(Color("AppCard"))

            Section("系統資訊") {
                LabeledContent("App 版本", value: feedback.appVersion)
                if let ios = feedback.iosVersion {
                    LabeledContent("iOS 版本", value: ios)
                }
                if let device = feedback.deviceModel {
                    LabeledContent("裝置型號", value: device)
                }
            }
            .listRowBackground(Color("AppCard"))

            Section("狀態") {
                HStack {
                    Text("處理狀態")
                    Spacer()
                    FeedbackStatusBadge(status: feedback.status)
                }
                if let reply = feedback.developerReply, !reply.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("開發者回覆")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(reply)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listRowBackground(Color("AppCard"))

            if !feedback.screenshots.isEmpty {
                Section("附加截圖") {
                    Text("共 \(feedback.screenshots.count) 張截圖")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color("AppCard"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
        .navigationTitle("回饋詳情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FeedbackStatusBadge

struct FeedbackStatusBadge: View {
    let status: String

    private var label: String {
        switch status {
        case "read":    return "已讀"
        case "replied": return "已回覆"
        default:        return "待處理"
        }
    }

    private var color: Color {
        switch status {
        case "read":    return .blue
        case "replied": return .green
        default:        return .secondary
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - RemoteFeedback

struct RemoteFeedback: Codable, Identifiable {
    let id: UUID
    let category: String
    let title: String
    let content: String
    let appVersion: String
    let iosVersion: String?
    let deviceModel: String?
    let email: String?
    let screenshots: [String]
    let status: String
    let developerReply: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case title
        case content
        case appVersion = "app_version"
        case iosVersion = "ios_version"
        case deviceModel = "device_model"
        case email
        case screenshots
        case status
        case developerReply = "developer_reply"
        case createdAt = "created_at"
    }
}
