import SwiftUI
import SwiftData

struct AddJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let team: Team
    let initialDate: Date

    @State private var date: Date
    @State private var content = ""
    @State private var showingDuplicateAlert = false

    @Query private var allJournals: [Journal]

    var existingDates: [Date] {
        allJournals
            .filter { $0.teamID == team.id }
            .map { Calendar.current.startOfDay(for: $0.date) }
    }

    var isDuplicate: Bool {
        existingDates.contains(Calendar.current.startOfDay(for: date))
    }

    init(team: Team, initialDate: Date) {
        self.team = team
        self.initialDate = initialDate
        let clamped = max(team.departureDate, min(initialDate, team.returnDate))
        _date = State(initialValue: clamped)
    }

    var isFormValid: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("日期") {
                    DatePicker(
                        "日期",
                        selection: $date,
                        in: team.departureDate...team.returnDate,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "zh_TW"))
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("記錄今天發生的事…")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $content)
                            .font(.body)
                            .frame(minHeight: 200)
                    }
                } header: {
                    HStack {
                        Text("內容")
                            .font(.footnote)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            insertPrefix("!!")
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                Text("重要事項")
                                    .font(.caption)
                            }
                            .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)

                        Button {
                            insertPrefix("//")
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.caption)
                                Text("意見反應")
                                    .font(.caption)
                            }
                            .foregroundStyle(Color(hex: "5B8CDB"))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }
                }
            }
            .alert("此日期已有日誌", isPresented: $showingDuplicateAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text("這一天已有日誌紀錄，請選擇其他日期。")
            }
            .navigationTitle("新增日誌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") {
                        if isDuplicate {
                            showingDuplicateAlert = true
                        } else {
                            saveJournal()
                        }
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func insertPrefix(_ prefix: String) {
        if content.isEmpty {
            content = prefix + " "
        } else if content.hasSuffix("\n") {
            content += prefix + " "
        } else {
            content += "\n" + prefix + " "
        }
    }

    private func saveJournal() {
        let journal = Journal(
            teamID: team.id,
            date: date,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(journal)
        dismiss()
    }
}
