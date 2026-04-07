import SwiftData
import SwiftUI

struct JournalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let journal: Journal
    let team: Team

    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 日期標題
                VStack(alignment: .leading, spacing: 4) {
                    Text("第\(journal.dayNumber(from: team.departureDate))天")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(journal.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // 日誌內容
                Text(journal.content)
                    .font(.body)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 40)

                // 更新時間
                Text("最後更新：\(journal.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .navigationTitle("第\(journal.dayNumber(from: team.departureDate))天")
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
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditJournalView(journal: journal, team: team)
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
}
