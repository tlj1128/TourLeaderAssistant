import SwiftData
import SwiftUI

struct JournalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let journal: Journal
    let team: Team

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy 年 M 月 d 日"
        return f.string(from: journal.date)
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 標題卡
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("第 \(journal.dayNumber(from: team.departureDate)) 天")
                                .font(.title).fontWeight(.bold)
                                .foregroundStyle(Color("AppAccent"))
                            Spacer()
                        }
                        Text(formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(Color(.systemGray))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("AppCard"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)

                    // 內容卡
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(contentBlocks, id: \.id) { block in
                            journalBlock(block)
                            if block.id != contentBlocks.last?.id {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(Color("AppCard"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)

                    // 更新時間
                    Text("最後更新：\(journal.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Color(.systemGray3))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(16)
            }
        }
        .navigationTitle("第 \(journal.dayNumber(from: team.departureDate)) 天")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEdit = true
                    } label: {
                        Label("編輯", systemImage: "pencil")
                    }
                    Button {
                        UIPasteboard.general.string = journal.content
                    } label: {
                        Label("複製內容", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color("AppAccent"))
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditJournalView(journal: journal, team: team)
                .appDynamicTypeSize(textSizePreference)
        }
        .confirmationDialog("確認刪除？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("刪除", role: .destructive) {
                modelContext.delete(journal)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("刪除後無法復原")
        }
    }

    // MARK: - 內容解析

    struct ContentBlock: Identifiable {
        let id = UUID()
        let type: BlockType
        let text: String

        enum BlockType {
            case important, feedback, normal
        }
    }

    var contentBlocks: [ContentBlock] {
        let lines = journal.content.components(separatedBy: "\n")
        var blocks: [ContentBlock] = []
        var normalLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("!!") {
                if !normalLines.isEmpty {
                    blocks.append(ContentBlock(type: .normal, text: normalLines.joined(separator: "\n")))
                    normalLines = []
                }
                let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                blocks.append(ContentBlock(type: .important, text: text))
            } else if trimmed.hasPrefix("//") {
                if !normalLines.isEmpty {
                    blocks.append(ContentBlock(type: .normal, text: normalLines.joined(separator: "\n")))
                    normalLines = []
                }
                let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                blocks.append(ContentBlock(type: .feedback, text: text))
            } else {
                normalLines.append(line)
            }
        }
        if !normalLines.isEmpty {
            blocks.append(ContentBlock(type: .normal, text: normalLines.joined(separator: "\n")))
        }
        return blocks
    }

    @ViewBuilder
    private func journalBlock(_ block: ContentBlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            switch block.type {
            case .important:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.body)
                    .padding(.top, 1)
            case .feedback:
                Image(systemName: "bubble.left.fill")
                    .foregroundStyle(Color(hex: "5B8CDB"))
                    .font(.body)
                    .padding(.top, 1)
            case .normal:
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Color(.systemGray3))
                    .font(.body)
                    .padding(.top, 1)
            }

            Text(block.text)
                .font(.subheadline)
                .lineSpacing(5)
                .foregroundStyle(block.type == .normal ? Color.primary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}
