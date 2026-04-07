import SwiftUI
import SwiftData

struct AddJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let team: Team
    let initialDate: Date

    @State private var date: Date
    @State private var content = ""

    init(team: Team, initialDate: Date) {
        self.team = team
        self.initialDate = initialDate
        _date = State(initialValue: initialDate)
    }

    var isFormValid: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("日期") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_TW"))
                }

                Section("內容") {
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("記錄今天發生的事…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $content)
                            .frame(minHeight: 200)
                    }
                }
            }
            .navigationTitle("新增日誌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") { saveJournal() }
                        .disabled(!isFormValid)
                        .fontWeight(.semibold)
                }
            }
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
