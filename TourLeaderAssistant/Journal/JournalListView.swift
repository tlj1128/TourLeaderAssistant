import SwiftUI
import SwiftData

struct JournalListView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @Query private var allJournals: [Journal]
    @State private var newEntryDate: Date? = nil
    @State private var showingAddJournal = false
    @State private var showingExport = false

    var journals: [Journal] {
        allJournals
            .filter { $0.teamID == team.id }
            .sorted { $0.date < $1.date }
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
        List {
            ForEach(journals) { j in
                NavigationLink {
                    JournalDetailView(journal: j, team: team)
                } label: {
                    JournalRowView(journal: j, departureDate: team.departureDate)
                }
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
                    .tint(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("每日日誌")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newEntryDate = Date()
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
                }
            }
        }
        .sheet(isPresented: $showingAddJournal) {
            AddJournalView(team: team, initialDate: newEntryDate ?? Date())
        }
        .sheet(isPresented: $showingExport) {
            ShareSheet(text: exportText)
        }
    }
}

struct JournalRowView: View {
    let journal: Journal
    let departureDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("第\(journal.dayNumber(from: departureDate))天")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(journal.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(journal.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}



struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
