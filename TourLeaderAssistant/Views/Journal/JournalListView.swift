import SwiftUI
import SwiftData

struct JournalListView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allJournals: [Journal]
    @State private var showingAddJournal = false
    @State private var showingExport = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    var journals: [Journal] {
        allJournals
            .filter { $0.teamID == team.id }
            .sorted { $0.date > $1.date }
    }

    var exportText: String {
        let lines = journals.map { j -> String in
            let day = j.dayNumber(from: team.departureDate)
            let dateStr = j.date.formatted(date: .abbreviated, time: .omitted)
            return "【第\(day)天 \(dateStr)】\n\(j.content)"
        }
        return lines.joined(separator: "\n\n")
    }

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if journals.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "book.pages")
                        .font(.title)
                        .foregroundStyle(Color("AppAccent").opacity(0.4))
                    Text("尚無日誌")
                        .font(.title3).fontWeight(.semibold)
                    Text("點右上角新增第一篇日誌")
                        .font(.subheadline)
                        .foregroundStyle(Color(.systemGray))
                }
            } else {
                List {
                    ForEach(journals) { j in
                        NavigationLink {
                            JournalDetailView(journal: j, team: team)
                        } label: {
                            JournalRowView(journal: j, departureDate: team.departureDate)
                        }
                        .listRowBackground(Color("AppCard"))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(j)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                UIPasteboard.general.string = j.content
                            } label: {
                                Label("複製", systemImage: "doc.on.doc")
                            }
                            .tint(Color(hex: "5B8CDB"))
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("每日日誌")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddJournal = true
                    } label: {
                        Label("新增日誌", systemImage: "plus")
                    }
                    Button {
                        showingExport = true
                    } label: {
                        Label("匯出全部", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color("AppAccent"))
                }
            }
        }
        .sheet(isPresented: $showingAddJournal) {
            AddJournalView(team: team, initialDate: Date())
                .appDynamicTypeSize(textSizePreference)
        }
        .sheet(isPresented: $showingExport) {
            ShareSheet(items: [exportText])
                .appDynamicTypeSize(textSizePreference)
        }
    }
}

struct JournalRowView: View {
    let journal: Journal
    let departureDate: Date

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: journal.date)
    }

    var previewText: String {
        let lines = journal.content.components(separatedBy: "\n")
        let preview = lines.first(where: {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.hasPrefix("!!") &&
            !$0.hasPrefix("//")
        }) ?? journal.content
        return preview.trimmingCharacters(in: .whitespaces)
    }

    var hasImportant: Bool {
        journal.content.contains("\n!!") || journal.content.hasPrefix("!!")
    }

    var hasFeedback: Bool {
        journal.content.contains("\n//") || journal.content.hasPrefix("//")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                // 天數標籤
                Text("第 \(journal.dayNumber(from: departureDate)) 天")
                    .font(.footnote).fontWeight(.semibold)
                    .foregroundStyle(Color("AppAccent"))

                Text(formattedDate)
                    .font(.footnote)
                    .foregroundStyle(Color(.systemGray))

                Spacer()

                // 前綴標記提示
                if hasImportant {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if hasFeedback {
                    Image(systemName: "bubble.left.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "5B8CDB"))
                }
            }

            Text(previewText)
                .font(.subheadline)
                .foregroundStyle(Color(.systemGray))
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
