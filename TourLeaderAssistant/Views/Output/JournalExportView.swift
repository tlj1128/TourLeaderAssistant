import SwiftUI
import SwiftData

struct JournalExportView: View {
    let team: Team
    @Query private var journals: [Journal]
    @Query private var expenses: [Expense]

    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var isGenerating = false
    @AppStorage("textSizePreference") private var textSizePreference = "standard"

    init(team: Team) {
        self.team = team
        let teamID = team.id
        self._journals = Query(
            filter: #Predicate<Journal> { $0.teamID == teamID },
            sort: [SortDescriptor(\Journal.date)]
        )
        self._expenses = Query(
            filter: #Predicate<Expense> { $0.teamID == teamID }
        )
    }

    var sortedJournals: [Journal] {
        journals.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("團體資訊") {
                    LabeledContent("團名", value: team.name)
                    LabeledContent("團號", value: team.tourCode)
                    LabeledContent("出發日期", value: team.departureDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("回國日期", value: team.returnDate.formatted(date: .abbreviated, time: .omitted))
                    if let pax = team.paxCount {
                        LabeledContent("人數", value: "\(pax) 人")
                    }
                }

                Section("日誌摘要") {
                    LabeledContent("已記錄天數", value: "\(journals.count) 天")
                    LabeledContent("總天數", value: "\(team.days) 天")
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(isGenerating ? "產生中..." : "產生報告書（純文字）")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(journals.isEmpty || isGenerating)
                }
            }
            .navigationTitle("帶團報告書")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                        .appDynamicTypeSize(textSizePreference)
                }
            }
        }
    }

    private func generate() {
        isGenerating = true
        Task {
            let url = await generateTXT()
            await MainActor.run {
                exportURL = url
                isGenerating = false
                showingShareSheet = true
            }
        }
    }

    private func generateTXT() async -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        dateFormatter.locale = Locale(identifier: "zh_TW")

        var lines: [String] = []

        // ── 標題 ──
        lines.append("═══════════════════════════════════")
        lines.append("帶團報告書")
        lines.append("═══════════════════════════════════")
        lines.append("")

        // ── 基本資訊 ──
        lines.append("【團體基本資訊】")
        lines.append("團名：\(team.name)")
        lines.append("團號：\(team.tourCode)")
        lines.append("出發日期：\(dateFormatter.string(from: team.departureDate))")
        lines.append("回國日期：\(dateFormatter.string(from: team.returnDate))")
        if let pax = team.paxCount {
            lines.append("出團人數：\(pax) 人")
        }
        if let rooms = team.roomCount {
            lines.append("房間數：\(rooms)")
        }
        if let notes = team.notes, !notes.isEmpty {
            lines.append("備註：\(notes)")
        }
        lines.append("")

        // ── 分類收集 ──
        var importantItems: [String] = []   // !! 開頭
        var feedbackItems: [String] = []    // // 開頭
        var dailyJournals: [(Journal, [String])] = []  // 一般內容

        for journal in sortedJournals {
            let contentLines = journal.content.components(separatedBy: "\n")
            var dailyLines: [String] = []

            for line in contentLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("!!") {
                    let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        importantItems.append(text)
                    }
                } else if trimmed.hasPrefix("//") {
                    let text = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        feedbackItems.append(text)
                    }
                } else {
                    dailyLines.append(line)
                }
            }

            // 去掉頭尾空行
            let trimmedDaily = dailyLines
                .drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
                .reversed()
                .drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
                .reversed()

            if !trimmedDaily.isEmpty {
                dailyJournals.append((journal, Array(trimmedDaily)))
            }
        }

        // ── 重要事項 ──
        if !importantItems.isEmpty {
            lines.append("【重要事項】")
            lines.append("───────────────────────────────────")
            for item in importantItems {
                lines.append("・\(item)")
            }
            lines.append("")
        }

        // ── 意見反應 ──
        if !feedbackItems.isEmpty {
            lines.append("【意見反應】")
            lines.append("───────────────────────────────────")
            for item in feedbackItems {
                lines.append("・\(item)")
            }
            lines.append("")
        }

        // ── 每日行程紀錄 ──
        if !dailyJournals.isEmpty {
            lines.append("【每日行程紀錄】")
            lines.append("───────────────────────────────────")
            lines.append("")

            for (journal, content) in dailyJournals {
                let day = journal.dayNumber(from: team.departureDate)
                let dateStr = dateFormatter.string(from: journal.date)
                lines.append("第 \(day) 天　\(dateStr)")
                lines.append("")
                for line in content {
                    lines.append(line)
                }
                lines.append("")
                lines.append("───────────────────────────────────")
                lines.append("")
            }
        }

        // ── 產生檔案 ──
        let content = lines.joined(separator: "\n")
        let fileName = "\(team.name)_帶團報告書.txt"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
